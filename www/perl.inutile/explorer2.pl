#!/usr/bin/perl

use strict;
#use warnings;
use DBI;
use CGI qw( -no_xhtml :standard start_ul); # make html 4.0 card
use CGI::Carp qw( fatalsToBrowser ); # display errors in browser
use Getopt::Long;
use LWP::UserAgent;
use utf8;

my $fullhtml;
my $maprest = "http://edit.africamuseum.be/edit_wp5/v1/areas.php";

# Gets parameters
################################################################
my ($dbase, $lang, $id, $card, $alph, $from, $to, $rank, $search, $searchtable, $searchid, $mode, $privacy);

GetOptions (	'db=s' => \$dbase, 'lang=s' => \$lang, 'id=s' => \$id, 'card=s' => \$card, 'alph=s' => \$alph, 'from=i' => \$from,
		'to=i' => \$to, 'rank=s' => \$rank, 'search=s' => \$search, 'searchtable=s' => \$searchtable, 'searchid=i' => \$searchid, 'mode=s' => \$mode, 'privacy=s' => \$privacy );

#unless ($dbase) 	{ $dbase = url_param('db') }

my %labels = (	'db' => $dbase, 'lang' => $lang, 'id' => $id, 'card' => $card, 'alph' => $alph, 'from' => $from, 'to' => $to,
		'rank' => $rank, 'search' => "$search", 'searchtable' => "$searchtable", 'searchid' => $searchid, 'mode' => $mode, 'privacy' => $privacy );
		
#if ($mode) { $mode = "&mode=$mode" }
#if ($privacy) { $privacy = "&privacy=$privacy" }

# Gets config
################################################################
my ($config_file, $synop_conf, $pdfdir);

if ($dbase eq 'flow') { $config_file = '/etc/flowexplorer.conf'; $synop_conf = '/etc/floweditor.conf'; $pdfdir = 'flowpdf'; }
elsif ($dbase eq 'flow2') { $config_file = '/etc/flowexplorer.conf'; $synop_conf = '/etc/floweditor.conf'; $pdfdir = 'flowpdf'; }
elsif ($dbase eq 'cool') { $config_file = '/etc/coolexplorer.conf'; $synop_conf = '/etc/cooleditor.conf'; $pdfdir = 'coolpdf'; }
elsif ($dbase eq 'psylles') { $config_file = '/etc/psyllesexplorer.conf'; $synop_conf = '/etc/psylleseditor.conf'; $pdfdir = 'psyllespdf'; }
elsif ($dbase eq 'aradides') { $config_file = '/etc/aradexplorer.conf'; $synop_conf = '/etc/aradeditor.conf'; $pdfdir = 'aradpdf'; }
elsif ($dbase eq 'coleorrhyncha') { $config_file = '/etc/peloridexplorer.conf'; $synop_conf = '/etc/pelorideditor.conf'; $pdfdir = 'pelopdf'; }
elsif ($dbase eq 'strepsiptera') { $config_file = '/etc/strepsexplorer.conf'; $synop_conf = '/etc/strepseditor.conf'; }
elsif ($dbase eq 'cipa') { $config_file = '/etc/cipaexplorer.conf'; }
my %scripts = ( 

	'test'		=> '/cgi-bin/test.pl?',
	'flow'		=> '/cgi-bin/flowsite.pl?page=explorer&',
	'flow2'		=> '/cgi-bin/flowsite2.pl?page=explorer&',
	'cool'		=> '/cool/database.php?',
	'psylles'	=> '/cgi-bin/psyllesexplorer.pl?',
	'aradides'	=> '/cgi-bin/aradexplorer.pl?',
	'coleorrhyncha'	=> '/cgi-bin/coleorrhyncha.pl?',
	'strepsiptera'	=> '/cgi-bin/strepsiptera.pl?',
	'cerambycidae'	=> '/cgi-bin/cerambycidae.pl?',
	'cipa'		=> '/cgi-bin/cipa/cipaexplorer.pl?'
);

my %states = (

	# They are used to call the subroutine that builds the corresponding card
	'top'          => \&topics_list, # goes to top list
	'families'     => \&families_list, # goes to families list
	'genera'       => \&genera_list, # goes to genera list
	'speciess' 	=> \&species_list, # goes to species list
	'authors'      => \&authors_list, # goes to authors list
	'publications' => \&publications_list, # goes to publications list
	'names'        => \&names_list, # goes to names list
	'repositories' => \&repositories_list, # goes to repositories list
	'eras'         => \&eras_list, #  goes to eras list
	'countries'    => \&countries_list, # goes to countries list
	'regions'	=> \&regions_list, # goes to biogeographic regions list
	'plants'       => \&plants_list, # goes to plants list
	'vernaculars'  => \&vernaculars, # makes the board
	'hosts'	=> \&associations, # makes the board
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

	'family'       => \&family_card, # goes to family card
	'genus'        => \&genus_card, # goes to genus card
	'subgenus'     => \&subgenus_card, # goes to genus card
	'species'      => \&species_card, # goes to species card
	'subspecies'   => \&subspecies_card, # goes to species card
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
	'host'		=> \&association, # makes the board
	'agent'        => \&agent_card, # goes to agent card
	'edition'      => \&edition_card, # goes to edition card
	'habitat'      => \&habitat_card, # goes to habitat card
	'locality'     => \&locality_card, # goes to locality card
	'capture'      => \&capture_card, # goes to capture technic card
	'type'       => \&type_card,
	'searching'    => \&search_results # display search string matching results
);

# Loads topics list contained in the configuration file
my @topics = qw(families genera speciess names publications authors countries regions localities habitats types repositories captures agents vernaculars);

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
unless ( exists $scripts{$dbase} ) { push(@msg, "db = $dbase");}
unless ( exists $states{$card} ) {  push(@msg, "card = $card");}

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
	
	unless ( $trans = read_lang($config) ) { error_msg( "lang = $lang" ); } 
	else { 
		unless ($dbase eq 'cool' or $dbase eq 'flow' or $dbase eq 'flow2' or $dbase eq 'strepsiptera') {
			$totop = a({-class=>'navlink', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=top"}, $trans->{'topics'}->{$lang});
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
													'id' 	=> 'nom',
													'ref' 	=> 'ref_nom',
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
									'foreign_joins' => 'LEFT JOIN noms_vernaculaires AS nv ON nv.index = tx.ref_nom',
									'order' => 'ORDER BY nom, transliteration'
						}	
			};
			
			$dbc->disconnect;
		}
		my $argus;
		if($card eq 'host' or $card eq 'hosts') { $argus = 'host' }
		$states{$card}->($argus);
	}
}
else { error_msg( join(br, @msg) );}

exit;

sub getPDF {
	my ($index) = @_;

	if (open(TEST, "/var/www/html/Documents/$pdfdir/$index.pdf") ) {
		return ' ' . a({-href=>"/$pdfdir/$index.pdf" }, img({-style=>'border: 0;', -src=>"/explorerdocs/pdflogo.jpg"}));
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
	$fullhtml = 	div({-class=>'explocontent'},
				div({-class=>'subject'}, $error),
				$msg
			);
		
	print $fullhtml;
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
			$txlist .= h2({-class=>'exploh2'}, $ptitle);
			$txlist .= start_ul({-class=>'exploul'});
		
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
							$element .= a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$row->[$i]"}, publication($row->[$i], 0, 1, $dbc)). ', ';
							#$element .= span({-style=>"color: #666666;"}, '[' . $row->[$i] . ']') . ', ';
						}
						elsif ($field->{'type'} eq 'foreign') {
							$element .= span({-style=>"color: #444444;"}, $title) . ' : ';
							if ($field->{'card'}) { $element .=  a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=".$field->{'card'}."&id=$row->[$i]"}, $retro_hash->{$field->{'thesaurus'}.$row->[$i]}) . ', '; }
							else { $element .=  span({-style=>"color: $color;"}, $retro_hash->{$field->{'thesaurus'}.$row->[$i]}) . ', '; }
						} 
						elsif ($field->{'type'} eq 'select') {
							$element .= span({-style=>"color: #444444;"}, $title) . ' : ';
							if (exists $field->{'labels'}) {
								if ($field->{'card'}) {
									$element .= a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=".$field->{'card'}."&id=$row->[$i]"}, $field->{'labels'}->{$row->[$i]}) . ', ';
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
				$txlist .= li({-class=>'exploli'}, substr($element, 0, -2));
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
	
	
	if ($dbase =~ m/psylles/) {
		my @topics_list;
		foreach (@topics) {
			my $class = 'exploa';
			#if ($mode eq $_) { $class = 'activetopic'; }
			#else { $class = 'exploa'; }
			my $href = "$scripts{$dbase}db=$dbase&lang=$lang&card=$_";
			push(@topics_list, a({-class=>"$class", -href=>$href}, $trans->{$_}->{$lang}));
		}
		$fullhtml = "<tr><td valign=center style='padding: 4px 0px 2px 0px; font-size: 16px;'>" . join('</td><td valign=center style=\'padding: 4px 2px 2px 2px; background: black; font-size: 10px;\'>|</td><td valign=center style=\'padding: 4px 0px 2px 0px; background: black; font-size: 16px;\'>', @topics_list) . "</td></tr>";
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
		#my $fa_list = start_ul({-class=>'exploul'});
		my $fa_list;
		while ( $sth->fetch() ){
			if ($doclogo) { $doclogo = '&nbsp;' . img({-src=>$doclogo, -style=>'width: 14px; border: 0; margin: 0; padding: 0;'}); }
			if ($docid) { $docid = a({-class=>'exploa', -style=>'margin-left: 20px;', -href=>$docid, -target=>'_blank'}, $doclogo . " $trans->{'id_key'}->{$lang} "); }
			$fa_list .= Tr(td({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=family&id=$taxonid"}, i("$name") . " $autority")), td($docid));
		}
		#$fa_list .= end_ul();
		$fa_list = table($fa_list);
		
		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{"families"}->{$lang}),
						#h3({-class=>'exploh3'}, "$fa_numb $trans->{'family(s)'}->{$lang}"),
						$fa_list
					)
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
			if ($url) { $url = a({-class=>'exploa', -style=>'', -href=>$url, -target=>'_blank'}, i("$name") . " $autority"); }
			$key_list .= Tr(td($url));
		}
		$key_list = table($key_list);
		
		my $prevnext;
		
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{'id_keys'}->{$lang}),
						$key_list
					)
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
			if ($url) { $url = a({-class=>'exploa', -style=>'', -href=>$url, -target=>'_blank'}, i("$name") . " $autority"); }
			$key_list .= Tr(td($url));
		}
		$key_list = table($key_list);
		
		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{'morphcards'}->{$lang}),
						$key_list
					)
				);
				
		print $fullhtml;
		
		$dbc->disconnect; # disconnection
	}
	else {} # Connection failed
}

# Genera list
#################################################################
sub genera_list {
	if ( my $dbc = db_connection($config) ) { # connection
		$dbc->{RaiseError} = 1; #TODO: enhance error message...
		
		# Get the number of genera to build up the list
		my $ge_numb = '';
		my $alphabet;
		
		my $sth = $dbc->prepare("SELECT count(*) FROM taxons AS t 
					LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
					LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN rangs AS r ON t.ref_rang = r.index
					WHERE r.en = 'genus' AND s.en = 'valid';");
		
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
						WHERE r.en = 'genus' AND s.en = 'valid'
						ORDER by nc.orthographe
						LIMIT 1;";
						
				my $sth = $dbc->prepare($req) or die $req;
				$sth->execute() or die $req;
				$sth->bind_columns( \( $alph ) );
				$sth->fetch();
				$sth->finish();
				
				$alph = lc(substr($alph, 0, 1));
			}
			
			my $vlreq = "	SELECT lower(substring(orthographe,1,1)) AS letter, count(*) 
					FROM taxons AS t 
					LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
					LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN rangs AS r ON t.ref_rang = r.index
					WHERE r.en = 'genus' AND s.en = 'valid'
					GROUP BY substring(orthographe,1,1) 
					HAVING count(*) > 0 
					ORDER BY lower(substring(orthographe,1,1));";
					
			my $vletters = request_hash($vlreq, $dbc, 'letter');
			
			$sth = $dbc->prepare("SELECT count(*) FROM taxons AS t 
						LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
						LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						LEFT JOIN rangs AS r ON t.ref_rang = r.index
						WHERE r.en = 'genus' AND s.en = 'valid'
						AND n.orthographe ILIKE '$alph%';");		
			
			$sth->execute( );
			$sth->bind_columns( \( $ge_numb ) );
			$sth->fetch();
			$sth->finish(); # finalize the request
			
			$alphabet = alpha_build($vletters);
		}
		else { $alph = '' }

		# Fetch genera
		my ( $taxonid, $name, $autority, $parent_name, $parent_taxon, $parent_rank, $docid);

		my $req = 	"SELECT t.index, n.orthographe, n.autorite, n2.orthographe, t.ref_taxon_parent, r2.en, d.url 
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
				WHERE r.en = 'genus' AND s.en = 'valid'
				AND s2.en = 'valid'
				AND (d.type = 'card' OR d.type IS NULL)
				AND n.orthographe ILIKE '$alph%'
				ORDER BY n.orthographe;";
	
		# Attention : ORDER BY LOWER ( n.orthographe ) doesn't work with $alph=ap ????
		$sth = $dbc->prepare($req);
		$sth->execute( );

		$sth->bind_columns( \( $taxonid, $name, $autority, $parent_name, $parent_taxon, $parent_rank, $docid ) );
		#my $ge_list = start_ul({-class=>'exploul'});
		my $ge_list;
		my $i = 0;
		my $nab;
		my $naval;
		my $test = 0;
		if ($to and $ge_numb > $to) {
			while ( $sth->fetch() ){

				if ($i % $to == 0 ) { $naval = substr($name, 0, 3)}
				elsif($i % $to == $to-1 or $i == $ge_numb-1) { 
					$naval .= " - " . substr($name, 0, 3);
					my $ff = int($i/$to) * $to;
					my $active;
					if ($ff == $from) { $active = 'font-size: 18px;'}
					$naval = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$card&from=$ff&alph=$alph"}, $naval );
					push(@{$nab}, $naval); 
					$naval = ''; 
				}

				if ($i >= $from and $i < $from + $to) {
					if ($parent_rank ne 'family') {
					       	($parent_name) = @{ request_row("SELECT parent_taxon_name($parent_taxon, 'family')", $dbc)}
					}
					if ($docid) { $test = 1; $docid = a({-class=>'exploa', -style=>'margin-left: 20px;', -href=>$docid, -target=>'_blank'}, img({-src=>"/explorerdocs/icon-fiche.png", -style=>'border: 0; margin: 0;'})); }					
					#$ge_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=genus&id=$taxonid"}, i("$name") . " $autority" ), " &nbsp; ($parent_name)" );
					$ge_list .= Tr(td({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=genus&id=$taxonid"}, i("$name") . " $autority")), td({-style=>'text-align: center;'}, $docid));
				}
				$i++;
			}
		}
		else {
			while ( $sth->fetch() ){
				if ($parent_rank ne 'family') {
					($parent_name) = @{ request_row("SELECT parent_taxon_name($parent_taxon, 'family')", $dbc)}
				}
				if ($docid) { $test = 1; $docid = a({-class=>'exploa', -style=>'margin-left: 20px;', -href=>$docid, -target=>'_blank'}, img({-src=>"/explorerdocs/icon-fiche.png", -style=>'border: 0; margin: 0;'})); }					
				#$ge_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=genus&id=$taxonid"}, i("$name") . " $autority" ), " &nbsp; ($parent_name)" );
				$ge_list .= Tr(td({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=genus&id=$taxonid"}, i("$name") . " $autority")), td({-style=>'text-align: center;'}, $docid));
			}
		}
		#$ge_list .= end_ul();
		if ($test) { $ge_list = Tr(td('&nbsp;'), td(h3({-class=>'exploh3', -style=>'font-size: 12px; margin: 0px; padding: 0;'}, $trans->{'morphcards'}->{$lang}))) . $ge_list; }
		$ge_list = table({-style=>'margin: 0; padding: 0;'}, $ge_list);

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		
		$fullhtml =  	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{"genera"}->{$lang}), # title
						$alphabet,
						#h3({-class=>'exploh3'}, "$ge_numb $trans->{'genus(s)'}->{$lang}"),
						$ge_list
					)
				);
		
		print $fullhtml;

		$dbc->disconnect;
	}
	else {}
}

# Species list
#################################################################
sub species_list {
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
				WHERE r.en = 'species' AND s.en = 'valid';";
		
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
						WHERE r.en = 'species' AND s.en = 'valid'
						ORDER by nc.orthographe
						LIMIT 1;";
						
				my $sth = $dbc->prepare($req) or die $req;
				$sth->execute() or die $req;
				$sth->bind_columns( \( $alph ) );
				$sth->fetch();
				$sth->finish();
				
				$alph = lc(substr($alph, 0, 1));
			}
			
			my $vlreq = "	SELECT lower(substring(orthographe,1,1)) AS letter, count(*) 
					FROM taxons AS t 
					LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
					LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN rangs AS r ON t.ref_rang = r.index
					WHERE r.en = 'species' AND s.en = 'valid'
					GROUP BY substring(orthographe,1,1) 
					HAVING count(*) > 0 
					ORDER BY lower(substring(orthographe,1,1));";
					
			my $vletters = request_hash($vlreq, $dbc, 'letter');
			
			$req = "	SELECT count(*) 
					FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
					LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN rangs AS r ON t.ref_rang = r.index
					WHERE r.en = 'species' AND s.en = 'valid'
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

		$req = "SELECT t.index, nc.orthographe, nc.autorite, t.ref_taxon_parent
			FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
			LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
			LEFT JOIN statuts AS s ON txn.ref_statut = s.index
			LEFT JOIN rangs AS r ON t.ref_rang = r.index
			WHERE r.en = 'species' AND s.en = 'valid'
			AND nc.orthographe ILIKE '$alph%'
			ORDER BY nc.orthographe
			$bornes;";
		
		# Fetch species from DB
		my ( $taxonid, $name, $autority, $ref_taxon_parent );
		$sth = $dbc->prepare($req) or die $req;

		$sth->execute() or die $req;
		
		$sth->bind_columns( \( $taxonid, $name, $autority, $ref_taxon_parent ) );
		my $sp_list = start_ul({-class=>'exploul'});
		while ( $sth->fetch() ){
			my $parent_name = [];
			#$ref_taxon_parent and $parent_name = request_row( "SELECT parent_taxon_name($ref_taxon_parent,'family');", $dbc );
			$sp_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$taxonid"}, i("$name") . " $autority" ), " $parent_name->[0]" );
		}
		$sp_list .= end_ul();
		
		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{"speciess"}->{$lang}),
						$alphabet,
						#h3({-class=>'exploh3'}, "$sp_numb $trans->{'species(s)'}->{$lang}"),
						$sp_list
					)
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
	
	my ($ordstr, $famstr, $genstr, $spestr) = ($trans->{'ord_key'}->{$lang}, $trans->{'families'}->{$lang}, $trans->{'genera'}->{$lang}, $trans->{'speciess'}->{$lang});
	
	if ($rank eq 'order') { $ordstr = span({-class=>'xsection'}, $ordstr) }
	elsif ($rank eq 'family') { $famstr = span({-class=>'xsection'}, $famstr) }
	elsif ($rank eq 'genus') { $genstr = span({-class=>'xsection'}, $genstr) }
	elsif ($rank eq 'species') { $spestr = span({-class=>'xsection'}, $spestr) }
	else { $rank = 'species'; $spestr = span({-class=>'xsection'}, $spestr) }
	
	my @rankselect = (	
				#a({-class=>'section', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=names&rank=order"}, $ordstr),
				a({-class=>'section', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=names&rank=family"}, $famstr),
				a({-class=>'section', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=names&rank=genus"}, $genstr),
				a({-class=>'section', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=names&rank=species"}, $spestr) );
	
	
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
					
					$alph = lc(substr($alph, 0, 1));
				}
				
				my $vlreq = "	SELECT lower(substring(orthographe,1,1)) AS letter, count(*) 
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
		my ( $ord, $fam, $gen, $spec );
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
		
		if ( $rank eq 'order' or $rank eq 'suborder' ){
			foreach my $name ( @{$names} ){
				if ( $name->[3] eq 'valid' ){
					$ord .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$rank&id=$name->[0]"}, i($name->[1]) . " $name->[2] &nbsp;" . b("$name->[4]") ) );				
				}
				else {
					$ord .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$name->[0]"}, i($name->[1]) . " $name->[2] &nbsp;" . b($name->[4]) ) );
				}
			}
		}
		elsif ( $rank eq 'super family' or $rank eq 'family' or $rank eq 'subfamily' ){
			foreach my $name ( @{$names} ){
				if ( $name->[3] eq 'valid' ){
					$fam .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$rank&id=$name->[6]"}, i($name->[1]) . " $name->[2] &nbsp;" . b("$name->[4]") ) );				
				}
				else {
					$fam .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$name->[0]"}, i($name->[1]) . " $name->[2] &nbsp;" . b($name->[4]) ) );
				}
			}
		}
		elsif ( $rank eq 'genus' or $rank eq 'subgenus' ){
			foreach my $name ( @{$names} ){	
				if ( $name->[3] eq 'valid' ){
                                        $gen .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$rank&id=$name->[6]"}, i($name->[1]) . " $name->[2] &nbsp;" . b("$name->[4]") ) );
				}
				else {
					$gen .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$name->[0]"}, i($name->[1]) . " $name->[2] &nbsp;" . b($name->[4]) ) );
				}
			}
		}
		elsif ( $rank eq 'super species' or $rank eq 'species' or $rank =~ m/subspecies/ ){
			foreach my $name ( @{$names} ){
				if ( $name->[3] eq 'valid' ){
					$spec .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$rank&id=$name->[6]"}, i($name->[1]) . " $name->[2] &nbsp;" . b("$name->[4]")) );
				}
				else {
					$spec .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$name->[0]"}, i($name->[1]) . " $name->[2] &nbsp;" . b($name->[4]) ) );
				}
			}
		}
		
		# conditionaly builds names lists
		my $html;
		$html .= div({-class=>'navigdiv'}, join(' / ', @rankselect));
		$html .= $alphab;
		if ( $ord ){
			#$html .= h3({-class=>'exploh3'}, "$na_numb->[0] $trans->{'name(s)'}->{$lang}");
			$html .= ul({-class=>'exploul'}, $ord);
		}
		if ( $fam ){
			#$html .= h3({-class=>'exploh3'}, "$na_numb->[0] $trans->{'name(s)'}->{$lang}");
			$html .= ul({-class=>'exploul'}, $fam);
		}
		if ( $gen ){
			#$html .= h3({-class=>'exploh3'}, "$na_numb->[0] $trans->{'name(s)'}->{$lang}");
			$html .= ul({-class=>'exploul'}, $gen);
		}
		if ( $spec ){
			#$html .= h3({-class=>'exploh3'}, "$na_numb->[0] $trans->{'name(s)'}->{$lang}");
			$html .= ul({-class=>'exploul'}, $spec);
		}

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'explocontent'},
					div({-class=>'navup'},
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{"names"}->{$lang}),
						$html
					)
				);
				
		print $fullhtml;

		$dbc->disconnect; 
	}
	else {
		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{"names"}->{$lang}),
						div({-class=>'navigdiv'}, join(' / ', @rankselect))
					)
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
						ORDER by reencodage(nom)
						LIMIT 1;";
						
				my $sth = $dbc->prepare($req) or die $req;
				$sth->execute() or die $req;
				$sth->bind_columns( \( $alph ) );
				$sth->fetch();
				$sth->finish();
				
				$alph = lc(substr($alph, 0, 1));
			}
			
			$au_numb = request_row("SELECT count(*) FROM auteurs WHERE reencodage(nom) ILIKE '$alph%';",$dbc);
			
			my $vlreq = "	SELECT lower(substring(reencodage(nom),1,1)) AS letter, count(*) 
					FROM auteurs AS a
					WHERE ((SELECT count(*) FROM noms_x_auteurs AS nxa LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = nxa.ref_nom WHERE nxa.ref_auteur = a.index AND txn.ref_statut != (SELECT index FROM statuts WHERE en = 'wrong spelling')) > 0
					OR (SELECT count(*) FROM auteurs_x_publications WHERE ref_auteur = a.index) > 0)
					GROUP BY substring(reencodage(nom),1,1) 
					HAVING count(*) > 0 
					ORDER BY lower(substring(reencodage(nom),1,1));";
					
			my $vletters = request_hash($vlreq, $dbc, 'letter');
			
			$alphabet = alpha_build($vletters);
		}
		else { $alph = '' }
		
		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }
		
		my $authors = request_tab("SELECT index, nom, prenom FROM auteurs AS a
						WHERE reencodage(a.nom) ILIKE '$alph%'
						AND ((SELECT count(*) FROM noms_x_auteurs AS nxa LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = nxa.ref_nom WHERE nxa.ref_auteur = a.index AND txn.ref_statut != (SELECT index FROM statuts WHERE en = 'wrong spelling')) > 0
						OR (SELECT count(*) FROM auteurs_x_publications WHERE ref_auteur = a.index) > 0)
						ORDER BY reencodage(nom), prenom
						$bornes;",$dbc);
						
		my $authors_tab = ul({-class=>'exploul'}, map { li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=author&id=$_->[0]"}, "$_->[1] $_->[2]" ) )} @{$authors});
		
		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{"authors"}->{$lang}),
						$alphabet,
						#h3({-class=>'exploh3'}, "$au_numb->[0] $trans->{'authors'}->{$lang}"),
						$authors_tab
					)
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
		
		my $sections = [];		
		my $distrib;
		my $secsize;
		
		
		my ($nbpubs) = @{ request_row('SELECT count(*) FROM publications WHERE index in (SELECT DISTINCT ref_publication FROM auteurs_x_publications);', $dbc)};
		if ($nbpubs > 2000) { $secsize = int($nbpubs / 200) } else {  $secsize = 6 }
		my $default = int($nbpubs/$secsize);
				
		my $pubids;
		my $publist = start_ul({-class=>'exploul', -id=>'pubul'});
		
		my $dreq = 'SELECT reencodage(nom), count(*), substr(reencodage(nom), 0, 5) FROM auteurs_x_publications LEFT JOIN auteurs ON ref_auteur = index WHERE position = 1 GROUP BY nom ORDER BY upper(reencodage(nom));';
		my $distrib = request_tab($dreq, $dbc);
		
		my $offset = 0;
		my $limit = 0;
		my $cut;

		if ($nbpubs > $default) {
	
			foreach my $author ( @{$distrib} ){
				
				my $substr = $author->[2];
				unless ($limit) { $cut = $substr }
				$limit += $author->[1];
				if ($limit > $default or $offset + $limit >= $nbpubs) { 
					if ($substr ne $cut) { $cut .= " - " . $substr }
					my $active;
					if ($offset == $from) { 
						$cut = span({-class=>'xsection'}, $cut);
						$pubids = request_tab("	SELECT p.index FROM publications AS p 
									LEFT JOIN auteurs_x_publications AS axp ON p.index = axp.ref_publication
									LEFT JOIN auteurs AS a ON axp.ref_auteur = a.index 
									WHERE axp.position = 1
									ORDER BY upper(reencodage(a.nom)), annee, titre
									OFFSET $offset LIMIT $limit;", $dbc);
						
						foreach my $id (@{$pubids}) {
							my $pub = pub_formating($id->[0], $dbc );
							$publist .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$id->[0]"}, $pub ) . getPDF($id->[0]) );
						}
					}
					my $link = a({-class=>'section', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$card&from=$offset&to=$limit"}, $cut);
					
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
						ORDER BY a.nom, annee, titre;", $dbc);
			
			foreach my $id (@{$pubids}) {
				my $pub = pub_formating($id->[0], $dbc );
				$publist .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$id->[0]"}, $pub ) . getPDF($id->[0]) );
			}
		}
		
		$publist .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
				
		$fullhtml =  	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{"publications"}->{$lang}),
						div({-class=>'navigdiv'}, join(' / ',@{$sections})),
						$publist
					)
				);
				
		print $fullhtml;

		$dbc->disconnect;
	}
	else {}
}

# Plants list
#################################################################
sub plants_list {
	if ( my $dbc = db_connection($config) ) {
		
		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }
		
		my $plantsids = request_tab("SELECT index, ref_valide
						FROM plantes
						WHERE get_host_plant_name(index) ILIKE '$alph%'
						AND index in (SELECT distinct ref_plante FROM taxons_x_plantes)
						AND ref_rang != 2
						ORDER BY get_host_plant_name(index)
						$bornes;",$dbc);
		
		my $plants;
		foreach (@{$plantsids}) {
			my ($pid, $pvid) = @{$_};
			$pvid = $pvid || 0;
			push(@{$plants}, [$pid, $pvid, @{@{request_tab("SELECT p.nom, p.autorite, p.famille, p.rang, pv.nom, pv.autorite, pv.famille, pv.rang
							FROM get_host_plant($pid) AS p
							LEFT JOIN get_host_plant($pvid) AS pv ON 1=1;",$dbc)}->[0]}]
				);
		}
				
		my $plants_list .= start_ul({-class=>'exploul'});
		
		my $famord;
		my $alphord;
		if (url_param('mode') eq 'family') {
			my @sorted = sort {$a->[4] cmp $b->[4]} @{$plants};
			
			my $current;
			foreach my $row ( @sorted ){
				my $pdisp;
				my $cardid = $row->[1] || $row->[0];
				$pdisp = i("$row->[2]")." $row->[3]";
				if (!$current) { $plants_list .= li({-class=>'exploli'}, br . div($row->[4])); $current = $row->[4]; }
				elsif ($row->[4] ne $current) { $plants_list .= li({-class=>'exploli'}, br . div($row->[4])); $current = $row->[4]; }
				$plants_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plant&id=$cardid"}, $pdisp));
			}
			
			$famord = span({-class=>'xletter'}, $trans->{'family'}->{$lang});
			$alphord = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plants"}, $trans->{'alphabetic'}->{$lang});
		}
		else {
			my @sorted = sort {$a->[2] cmp $b->[2]} @{$plants};
			
			$plants_list .= br;
			foreach my $row ( @sorted ){
				my $pdisp;
				my $cardid = $row->[1] || $row->[0];
				$row->[4] = $row->[4] ? " ($row->[4])" : '';
				$pdisp = i("$row->[2]")." $row->[3]$row->[4]";
				$row->[7] = $row->[7] ? " $row->[7]" : '';
				$row->[8] = $row->[8] ? " ($row->[8])" : '';
				if ($row->[1]) { $pdisp .= " [ $row->[6]$row->[7]$row->[8] ]" }
				$plants_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plant&id=$cardid"}, $pdisp));
			}
			
			$famord = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plants&mode=family"}, $trans->{'family'}->{$lang});
			$alphord = span({-class=>'xletter'}, $trans->{'alphabetic'}->{$lang});
		}

		if (url_param('mode') eq 'full') {
				$plants_list .= br . hr . br;
				
				my $plantsgenera = request_tab("SELECT nom FROM plantes WHERE ref_rang IN (SELECT index FROM rangs WHERE en in ('genus')) ORDER BY nom;",$dbc);
				
				foreach my $row ( @{$plantsgenera} ){
					my $species = request_tab("	SELECT DISTINCT txp.ref_taxon, nc.orthographe, nc.autorite 
												FROM taxons_x_plantes AS txp 
												LEFT join taxons_x_noms AS txn ON txp.ref_taxon = txn.ref_taxon 
												LEFT join noms_complets AS nc ON nc.index = txn.ref_nom 
												WHERE txn.ref_statut = 1 
												AND get_host_plant_name(ref_plante) LIKE '$row->[0] %'
												ORDER by nc.orthographe, nc.autorite;",$dbc);
					
					$plants_list .= li({-class=>'exploli'}, $row->[0]);
					foreach my $sp ( @{$species} ){
						$plants_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$sp->[0]"}, i($sp->[1]) . " " . $sp->[2]));
					}
				}
				
		}

		$plants_list .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{"plants"}->{$lang}),
						#h3({-class=>'exploh3', -style=>'display: inline;'}, scalar(@{$plants}, @{$plants2}) . " $trans->{'hostplant(s)'}->{$lang}") .
						#"$trans->{'sortedby'}->{$lang} " . $alphord . " / " . $famord, br,
						$plants_list
					)
				);
				
		print $fullhtml;
			
		$dbc->disconnect;
	}
	else {}
}

# Associated taxa list
#################################################################
sub associations {
	
	my ($type) = @_;
	
	if ( my $dbc = db_connection($config) ) {
		
		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }
		
		my $associes = request_tab("SELECT DISTINCT ta.index, (get_taxon_associe(ta.index)).*
						FROM taxons_associes ta
						INNER JOIN taxons_x_taxons_associes AS txt ON ta.index = txt.ref_taxon_associe
						LEFT JOIN types_association AS ty ON ty.index = txt.ref_type_association
						WHERE get_taxon_associe_full_name(ta.index) ILIKE '$alph%'
						AND ty.en = '$type'
						ORDER BY nom
						$bornes;",$dbc);
		
		my $associates_list;
		my $name_list = start_ul({-class=>'exploul'});
		my $higher_list;
				
		my $famord;
		my $alphord;
		if (url_param('mode') eq 'family') {
			my @sorted = sort {$a->[3] cmp $b->[3] || $a->[1] cmp $b->[1]} @{$associes};
			
			my $current;
			foreach my $row ( @sorted ){
				my $str = i($row->[1]);
				if ($row->[2]) { $str .= " $row->[2]" }
				my $higher = $row->[3];
				if ($row->[4]) { $higher .= " ($row->[4])" }
								
				if (!$current or $higher ne $current) { $name_list .= li({-class=>'exploli'}, br . div($higher)); $current = $higher; }
				
				$name_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$type&id=$row->[0]"}, $str));
			}
			
			$famord = span({-class=>'xletter'}, $trans->{'family'}->{$lang});
			$alphord = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$type"."s"}, $trans->{'alphabetic'}->{$lang});
		}
		else {			
			#$higher_list = start_ul({-class=>'exploul'});
			#$higher_list .= br;
			$name_list .= br;
			foreach my $row ( @{$associes} ){
				my $str = i($row->[1]);
				if ($row->[2]) { $str .= " $row->[2]" }
				my $higher;
				if ($row->[3]) { $higher .= "&nbsp; $row->[3]" }
				if ($row->[4]) { $higher .= " ($row->[4])" }
				
				$name_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$type&id=$row->[0]"}, $str) . $higher);
				#$higher_list .= li({-class=>'exploli'}, $higher);
			}
			
			$famord = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$type"."s&mode=family"}, $trans->{'family'}->{$lang});
			$alphord = span({-class=>'xletter'}, $trans->{'alphabetic'}->{$lang});
			#$higher_list .= end_ul();
		}
		$name_list .= end_ul();
		if ($higher_list) {
			$associates_list = 	div({-style=>'display: table;'}, 
							div({-style=>'display: table-cell; padding-right: 10px;'}, $name_list),
							div({-style=>'display: table-cell;'}, $higher_list)
						);
		}
		else {
			$associates_list = $name_list;
		}
		
		$fullhtml =  	div({-class=>'explocontent'},
							div({-class=>'carddiv'},
								h2({-class=>'exploh2'}, ucfirst($trans->{$type."(s)"}->{$lang})),
								span({-class=>'text'}, "$trans->{'sortedby'}->{$lang} ") . $alphord . " / " . $famord, br,
								$associates_list
							)
						);
				
		print $fullhtml;
			
		$dbc->disconnect;
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
		
			unless($alph) { $alph = 'a' }
			
			$cn_numb = request_row( "SELECT count(*) FROM pays
							WHERE $lang ILIKE '$alph%'
							AND $lang NOT LIKE '%(%'
							AND index in (SELECT distinct ref_pays from taxons_x_pays)
							$bornes;", $dbc);
			
			my $vlreq = "	SELECT lower(substring($lang,1,1)) AS letter, count(*) 
					FROM pays
					WHERE $lang NOT LIKE '%(%'
					AND index in (SELECT distinct ref_pays from taxons_x_pays)
					GROUP BY substring($lang,1,1) 
					HAVING count(*) > 0 
					ORDER BY lower(substring($lang,1,1));";
					
			my $vletters = request_hash($vlreq, $dbc, 'letter');

			$alphabet = alpha_build($vletters);
		}
		else { $alph = '' }
		
		my $countries = request_tab("SELECT index, $lang FROM pays
						WHERE $lang ILIKE '$alph%'
						AND $lang NOT LIKE '%(%'
						AND index in (SELECT distinct ref_pays from taxons_x_pays)
						ORDER BY reencodage($lang)
						$bornes;",$dbc);

		my $countries_list = start_ul({-class=>'exploul'});
		foreach my $row ( @{$countries} ){
			$countries_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=$row->[0]"}, $row->[1] ) );
		}
		$countries_list .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{"geodistribution"}->{$lang}),
						$alphabet,
						#h3({-class=>'exploh3'}, "$cn_numb->[0] $trans->{'countries'}->{$lang}"),
						$countries_list
					)
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
			
			my $html;
			
			my $req = "		SELECT i.index, i.icone_url, txn.ref_taxon, nc.index, nc.orthographe, nc.autorite, i.url, r.en
							FROM noms_x_images AS nxi
							LEFT JOIN images as i ON nxi.ref_image = i.index
							LEFT JOIN noms_complets AS nc ON nc.index = nxi.ref_nom
							LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = nxi.ref_nom
							LEFT JOIN rangs AS r ON r.index = nc.ref_rang 
							ORDER BY nc.orthographe, i.index";
			
			my $images = request_tab($req,$dbc);			

			if (scalar(@{$images})) {
				
				$html .= h2({-class=>'exploh2'}, ucfirst($trans->{"type_img(s)"}->{$lang})) . p . 
				a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$images->[0][7]&id=$images->[0][2]"}, i("$images->[0][4]") .  " $images->[0][5]") . p;
				my $current = $images->[0][3];
				foreach my $row ( @{$images} ){
						if ($row->[3] ne $current) {
							$html .= div({-style=>'clear: both;'}) . br . p . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$images->[0][7]&id=$row->[2]"}, i("$row->[4]") .  " $row->[5]") . p;
							$current = $row->[3];
						}
						
						if ($dbase eq 'cool') {
							$html .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"window.open('$row->[6]', '', 'toolbar=0, location=0, scrollbars=1, directories=0, status=0, resizable=1, width=1100, height=800');"}, img({-src=>"$row->[1]", -style=>'border: 0; margin: 0;'})));
						}
						else {
							$html .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, 
								a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=image&id=$row->[0]&search=nom"}, img({-src=>"$row->[1]", -style=>'border: 0; margin: 0;'}))
							);
						}
				}
				$html .= div({-style=>'clear: both;'}) . br;
			}
			
			$req = "		SELECT i.index, i.icone_url, txi.ref_taxon, nc.index, nc.orthographe, nc.autorite, i.url, r.en
							FROM taxons_x_images AS txi
							LEFT JOIN images as i ON txi.ref_image = i.index
							LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = txi.ref_taxon
							LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
							LEFT JOIN rangs AS r ON r.index = nc.ref_rang 
							WHERE txn.ref_statut = 1
							ORDER BY nc.orthographe, i.index";
			
			$images = request_tab($req,$dbc);
			
			
			if (scalar(@{$images})) {
				
				if ($html) { $html .= br; }
				
				$html .= h2({-class=>'exploh2'}, ucfirst($trans->{"img(s)"}->{$lang})) . p . 
				a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$images->[0][7]&id=$images->[0][2]"}, i("$images->[0][4]") .  " $images->[0][5]") . p;
				my $current = $images->[0][3];
				foreach my $row ( @{$images} ){
						if ($row->[3] ne $current) {
							$html .= 	div({-style=>'clear: both;'}) . br . p . 
											a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$images->[0][7]&id=$row->[2]"}, i("$row->[4]") .  " $row->[5]"
										) . p;
							$current = $row->[3];
						}
						if ($dbase eq 'cool') {
							$html .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"window.open('$row->[6]', '', 'toolbar=0, location=0, scrollbars=1, directories=0, status=0, resizable=1, width=1100, height=800');"}, img({-src=>"$row->[1]", -style=>'border: 0; margin: 0;'})));
						}
						else {
							$html .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, 
									a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=image&id=$row->[0]&search=taxon"}, img({-src=>"$row->[1]", -style=>'border: 0; margin: 0;'}))
								);
						}
				}
				$html .= div({-style=>'clear: both;'}) . br;
			}
			
			
			my $fullhtml = 	div({-class=>'explocontent'},
								div({-class=>'carddiv'},
									$html
								)
							);
							
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
		my $list = start_ul({-class=>'exploul'});
				
		if ($mode eq 'country' or $mode eq 'language') {
			
			my $order;
			my $mode2;
			if ($mode eq 'country') {
				$langord = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=vernaculars&mode=language"}, $trans->{'langage'}->{$lang});
				$alphord = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=vernaculars"}, $trans->{'alphabetic'}->{$lang});
				$paysord = span({-class=>'xletter'}, $trans->{'pays'}->{$lang});
				$order = 'p.en, reencodage(v.nom), l.langage';
				$mode2 = 1;
			}
			elsif ($mode eq 'language') {
				$paysord = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=vernaculars&mode=country"}, $trans->{'pays'}->{$lang});
				$alphord = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=vernaculars"}, $trans->{'alphabetic'}->{$lang});
				$langord = span({-class=>'xletter'}, $trans->{'langage'}->{$lang});
				$order = 'l.langage, reencodage(v.nom), p.en';
				$mode2 = 0;
			}
			
			$sth = $dbc->prepare( "SELECT distinct v.index, v.nom, l.langage, p.en, txn.ref_taxon, nc.orthographe, nc.autorite, r.en, v.ref_pays, reencodage(v.nom)
						FROM noms_vernaculaires AS v
						LEFT JOIN taxons_x_vernaculaires AS txv ON v.index = txv.ref_nom
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
						if (!$current) { $list .= li({-class=>'exploli'}, br . div({-class=>'vernacular_subtitle'}, $pays)); $current = $pays; }
						elsif ($pays ne $current) { $list .= li({-class=>'exploli'}, br . div({-class=>'vernacular_subtitle'}, $pays)); $current = $pays; }
					}
					else {
						if ($current ne 'others') { $list .= li({-class=>'exploli'}, br . div({-class=>'vernacular_subtitle'}, $trans->{'unassigned'}->{$lang})); $current = 'others'; }
					}
				}
				else {
					if (!$current) { $list .= li({-class=>'exploli'}, br . div({-class=>'vernacular_subtitle'}, $langg)); $current = $langg; }
					elsif ($langg ne $current) { $list .= li({-class=>'exploli'}, br . div({-class=>'vernacular_subtitle'}, $langg)); $current = $langg; }
				}

				my $xpays;
				if ($pays) { $xpays = " in " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=$ref_pays"}, $pays) }
				$list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=vernacular&id=$id"}, "$name") . $xpays . " ($langg)" .
								$sep . " vernacular name of " . 
								a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$rk&id=$taxid"}, "$tax $aut" ) . p );
			}
		}
		else {
			$sth = $dbc->prepare( "SELECT distinct v.index, v.nom, l.langage, p.en, txn.ref_taxon, nc.orthographe, nc.autorite, r.en, v.ref_pays, reencodage(v.nom)
						FROM noms_vernaculaires AS v
						LEFT JOIN taxons_x_vernaculaires AS txv ON v.index = txv.ref_nom
						LEFT JOIN langages AS l ON v.ref_langage = l.index
						LEFT JOIN pays AS p ON v.ref_pays = p.index
						LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = txv.ref_taxon
						LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
						LEFT JOIN rangs AS r ON r.index = nc.ref_rang
						WHERE txn.ref_statut = 1
						ORDER BY reencodage(v.nom);");
			$sth->execute( );
			$sth->bind_columns( \( $id, $name, $langg, $pays, $taxid, $tax, $aut, $rk, $ref_pays, $reencode ) );
			
			$list .= li({-class=>'exploli'}, '&nbsp;');
			while ( $sth->fetch() ){	
				my $xpays;
				if ($pays) { $xpays = " in " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=$ref_pays"}, $pays) }
				$list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=vernacular&id=$id"}, "$name") . $xpays . " ($langg)" .
								$sep . " vernacular name of " . 
								a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$rk&id=$taxid"}, "$tax $aut" ) . p );
			}

			$langord = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=vernaculars&mode=language"}, $trans->{'langage'}->{$lang});
			$paysord = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=vernaculars&mode=country"}, $trans->{'pays'}->{$lang});
			$alphord = span({-class=>'xletter'}, $trans->{'alphabetic'}->{$lang});			
		}
		$list .= end_ul();
		
		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{'vernacular(s)'}->{$lang}),
						#h3({-class=>'exploh3'}, "$numb $trans->{'family(s)'}->{$lang}"),
						"$trans->{'sortedby'}->{$lang} " . $alphord . ' / ' . $paysord . ' / ' . $langord, p,
						$list
					)
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

		my $types_tab = start_ul({-class=>'exploul'});
		foreach my $row ( @{$types} ){
			$types_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=type&id=$row->[0]"}, $row->[1] ) );
		}
		$types_tab .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml = 	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{"TY_list"}->{$lang}),
						h3({-class=>'exploh3'}, "$tc_numb->[0] $trans->{'type_cat'}->{$lang}"),
						$types_tab
					)
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
		
		$fullhtml = 	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{"repositories"}->{$lang}),
						h3({-class=>'exploh3'}, scalar(@{$repositories}) . " $trans->{'repositories'}->{$lang}"),
						$de_tab
					)
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
		my $er_numb = request_row( "SELECT count(*) FROM periodes;", $dbc);
		
		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }

		# Fetch Eras list from DB
		my $eras = request_tab("SELECT index, $lang FROM periodes ORDER BY fr $bornes;",$dbc);

		my $eras_list = start_ul({-class=>'exploul'});
		foreach my $row ( @{$eras} ){
			$eras_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=era&id=$row->[0]"}, $row->[1] ) );
		}
		$eras_list .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml = 	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{"eras"}->{$lang}),
						#h3({-class=>'exploh3'}, "$er_numb->[0] $trans->{'eras'}->{$lang}"),
						$eras_list
					)
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


		my $re_tab = start_ul({-class=>'exploul'});
		foreach my $row ( @{$regions} ){
			if ($row->[2]) { $row->[1] .= " ($row->[2])" }
			$re_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=region&id=$row->[0]"}, $row->[1] ) );
		}
		$re_tab .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml = 	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{"regions"}->{$lang}),
						h3({-class=>'exploh3'}, "$re_numb->[0] $trans->{'regions'}->{$lang}"),
						$re_tab
					)
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

		my $a_tab .= start_ul({-class=>'exploul'});
		foreach my $agent ( @{$a_list} ){
			$a_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=agent&id=$agent->[0]"}, i("$agent->[1]") ) . " $agent->[2]" );
		}
		$a_tab .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml = 	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{"A_list"}->{$lang}),
						h3({-class=>'exploh3'}, "$a_numb->[0] $trans->{'agents'}->{$lang}"),
						$a_tab
					)
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

		$ed_tab .= start_ul({-class=>'exploul'});
		foreach my $edition ( @{$ed_list} ){
			$ed_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=edition&id=$edition->[0]"}, i("$edition->[1]") ) . " $edition->[2], $edition->[3]" );
		}
		$ed_tab .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml = 	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{"ED_list"}->{$lang}),
						h3({-class=>'exploh3'}, "$ed_numb->[0] $trans->{'editions'}->{$lang}"),
						$ed_tab
					)
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

		$ha_tab .= start_ul({-class=>'exploul'});
		foreach my $habitat ( @{$ha_list} ){
			$ha_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=habitat&id=$habitat->[0]"}, "$habitat->[1]" ) );
		}
		$ha_tab .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml = 	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{"habitat(s)"}->{$lang}),
						h3({-class=>'exploh3'}, "$ha_numb->[0] $trans->{'habitats'}->{$lang}"),
						$ha_tab
					)
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

		my $lo_tab = start_ul({-class=>'exploul'});
		foreach my $locality ( @{$lo_list} ){
			$lo_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=locality&id=$locality->[0]"}, "$locality->[1]" ) . ", $locality->[2], $locality->[3]" );
		}
		$lo_tab .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml = 	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{"LO_list"}->{$lang}),
						h3({-class=>'exploh3'}, "$lo_numb->[0] $trans->{'localities'}->{$lang}"),
						$lo_tab
					)
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

		my $ca_tab = start_ul({-class=>'exploul'});
		foreach my $capture ( @{$ca_list} ){
			$ca_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=capture&id=$capture->[0]"}, "$capture->[1]" ) );
		}
		$ca_tab .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml = 	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{"CA_list"}->{$lang}),
						h3({-class=>'exploh3'}, "$ca_numb->[0] $trans->{'captures'}->{$lang}"),
						$ca_tab
					)
				);
				
		print $fullhtml;
			
		$dbc->disconnect;
	}
	else {}
}

# Abstract panel
#################################################################
sub makeboard {

	my $config2 = {};
	if ( open(CONFIG, $synop_conf) ) {
		while (<CONFIG>) { 
			chomp; s/#.*//; s/^\s+//; s/\s+$//; next unless length;
			my ($option, $value) = split(/\s*=\s*/, $_, 2);
			$config2->{$option} = $value;
		}
		close(CONFIG);
	} else { die "No configuration file for synopsis edition could be found\n";}

	my $dbh = db_connection($config2) or die;
	my $sth = $dbh->prepare( 'DELETE FROM synopsis;' ) or die $dbh->errstr;
	$sth->execute() or  die $dbh->errstr;
	my $ranks_ids = get_rank_ids( $dbh );

	if ( my $dbc = db_connection($config) ) {

		my $orders =  request_tab("SELECT taxons.index, n.orthographe FROM taxons LEFT JOIN rangs ON taxons.ref_rang = rangs.index
			LEFT JOIN taxons_x_noms AS txn ON taxons.index = txn.ref_taxon
			LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
			WHERE en = 'order' AND txn.ref_statut = 1;",$dbc);

		foreach my $order ( @{$orders} ){
			
		my $req = "	SELECT taxons.index, n.orthographe FROM taxons LEFT JOIN rangs ON taxons.ref_rang = rangs.index
                		LEFT JOIN taxons_x_noms AS txn ON taxons.index = txn.ref_taxon
				LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
				WHERE en = 'suborder' AND txn.ref_statut = 1 
				AND taxons.ref_taxon_parent = $order->[0] 
				ORDER BY n.orthographe;";
				
		my $suborders =  request_tab($req,$dbc);		
		
		foreach my $suborder ( @{$suborders} ){
		
			my $superfamilies =  request_tab("SELECT taxons.index, n.orthographe FROM taxons LEFT JOIN rangs ON taxons.ref_rang = rangs.index
										LEFT JOIN taxons_x_noms AS txn ON taxons.index = txn.ref_taxon
										LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
										WHERE en = 'super family' AND txn.ref_statut = 1 AND taxons.ref_taxon_parent = $suborder->[0] order by n.orthographe;",$dbc);
			
			foreach my $superfamily ( @{$superfamilies}, @{$suborders} , @{$orders} ){
				my $families = request_tab("SELECT taxons.index, n.orthographe FROM taxons 
										LEFT JOIN rangs ON taxons.ref_rang = rangs.index
										LEFT JOIN taxons_x_noms AS txn ON taxons.index = txn.ref_taxon
										LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
										WHERE en = 'family' AND txn.ref_statut = 1 AND taxons.ref_taxon_parent = $superfamily->[0] order by n.orthographe;",$dbc);

				my $totnames;
				
				foreach my $family ( @{$families} ){
					$totnames = 0;	
					my $sp_sons = son_taxa($family->[0],  $ranks_ids->{"species"}->{"index"}, $dbc);
					my $ge_sons = son_taxa($family->[0],  $ranks_ids->{"genus"}->{"index"}, $dbc);

						my $getaxa = scalar  @{$ge_sons};
						my $genames;
						my $plants = 0;
						my $pays = 0;
						if ( $getaxa ) {					
							
							my $indexes = "(".join(',',@{$ge_sons}).")";
							
							$genames = request_row("SELECT count(distinct ref_nom) FROM taxons_x_noms WHERE ref_taxon IN $indexes;",$dbc);
							$genames = $genames->[0];
								
							my $pls = request_row("SELECT count(distinct ref_plante) FROM taxons_x_plantes WHERE ref_taxon IN $indexes;",$dbc);
							$plants += $pls->[0];
	
							my $pys = request_row("SELECT count(distinct ref_pays) FROM taxons_x_pays WHERE ref_taxon IN $indexes;",$dbc);
							$pays += $pys->[0];
	
							$totnames += $genames;
						}

						my $sptaxa = scalar  @{$sp_sons};
						my $spnames = 0;
						my $indexes;
						if ( $sptaxa ){
							my $indexes = "(".join(',',@{$sp_sons}).")";
							
							$spnames = request_row("SELECT count(ref_nom) FROM taxons_x_noms WHERE ref_taxon IN $indexes;",$dbc);    
							$spnames = $spnames->[0];
						
							my $pls = request_row("SELECT count(distinct ref_plante) FROM taxons_x_plantes WHERE ref_taxon IN $indexes;",$dbc);
							$plants += $pls->[0];

							my $pys = request_row("SELECT count(distinct ref_pays) FROM taxons_x_pays WHERE ref_taxon IN $indexes;",$dbc);
							$pays += $pys->[0];

							$totnames += $spnames;
						}
						
						if ($dbase eq 'cerambycidae') {
							$spnames = 40883;
							$genames = 7016;
							$pays = 44612;
							$totnames = $spnames + $genames;
						}
						
						my $flist = 'ordre, sous_ordre, super_famille, famille, genres, especes, noms, publications, plantes, pays';
						my $vlist = "'$order->[1]', '$suborder->[1]', '$superfamily->[1]', '$family->[1]', $getaxa, $sptaxa, $totnames, Null, $plants, $pays";
						my $req = "INSERT INTO synopsis ($flist) VALUES ($vlist);";

						my $sth = $dbh->prepare( $req ) or die "$dbh->errstr : $req";
						$sth->execute() or  die "$dbh->errstr : $req";
					}
				}
			}
		}

		board();
		$dbh->disconnect; 
		$dbc->disconnect; 
	}
	else {}
}

sub board {
	if ( my $dbc = db_connection($config) ) {
		my $pub_numb = request_row("SELECT count(*) FROM publications;",$dbc);
		my $counts = request_row("SELECT sum(genres), sum(especes), sum(noms), sum(plantes), sum(pays) FROM synopsis;",$dbc);
		my $rows = request_tab("SELECT ordre, sous_ordre, super_famille, famille, genres, especes, noms, publications, plantes, pays, modif FROM synopsis ORDER BY famille;",$dbc);
		my $last = $rows->[0][10];
		my $content;
		if ($card eq 'makeboard') { $card = 'board'}
		
		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		my ($ptit, $prow, $ptot);
		
		if ($dbase ne 'cool' and $dbase ne 'cerambycidae' and $dbase ne 'strepsiptera') { 
			$ptit = td({-class=>'synopla'}, b($trans->{'plants_associated'}->{$lang}));
			$ptot = td({-class=>'synopla'}, b($counts->[3]));
		}
		
		$content .= Tr({-class=>'synodiv'},
			td({-class=>'synofam', -style=>'padding-bottom: 10px;'}, b($trans->{'families'}->{$lang})),
			td({-class=>'synogen'}, b($trans->{'genera'}->{$lang})),
			td({-class=>'synospc'}, b($trans->{'speciess'}->{$lang})),
			td({-class=>'synonms'}, b($trans->{'names'}->{$lang})),
			$ptit,
			#td({-class=>'synopay'}, b($trans->{'countries'}->{$lang})),
			td({-class=>'synopub'}, b($trans->{'publications'}->{$lang}))
		);
				
		my ($ord, $subord, $supfam) = ($rows->[0][0], $rows->[0][1], $rows->[0][2]);
		#$content .= 	span({-class=>'synoord'}, $ord).
		#		span({-class=>'synosubord'}, $subord).
		#		span({-class=>'synosupfam'}, $supfam);
		
		if ($dbase eq 'flow' or $dbase eq 'flow2') {
			$content .= Tr({-class=>'synodiv'},
				td({-class=>'synofam'}, b($trans->{'total'}->{$lang})),
				td({-class=>'synogen'}, b($counts->[0])),
				td({-class=>'synospc'}, b($counts->[1])),
				td({-class=>'synonms'}, b($counts->[2])),
				$ptot,
				#td({-class=>'synopay'}, b($counts->[4])),
				td({-class=>'synopub'}, b($pub_numb->[0]))
			) . Tr(td({-style=>'height: 20px;'}));
		}

		foreach my $row (@{$rows}) {
			#unless ($row->[0] eq $ord) { $ord = $row->[0]; $content .= span({-class=>'synoord'}, $ord);}
			#unless ($row->[1] eq $subord) { $subord = $row->[1]; $content .= span({-class=>'synosubord'}, $subord);}
			#unless ($row->[2] eq $supfam) { $supfam = $row->[2]; $content .= span({-class=>'synosupfam'}, $supfam);}
			my $famlink = request_row("SELECT ref_taxon FROM taxons_x_noms WHERE ref_nom in (SELECT index FROM noms_complets WHERE orthographe = '$row->[3]') AND ref_statut = 1;",$dbc);
			$famlink = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=family&id=$famlink->[0]"}, $row->[3]);
			my $prow;
			if ($dbase ne 'cool' and $dbase ne 'cerambycidae' and $dbase ne 'strepsiptera') { $prow = td({-class=>'synopla'}, $row->[8]) }
			if ($dbase eq 'cerambycidae') { $row->[7] = $pub_numb->[0] }
			$content .= Tr({-class=>'synodiv'},
				td({-class=>'synofam'}, $famlink),
				td({-class=>'synogen'}, $row->[4]),
				td({-class=>'synospc'}, $row->[5]),
				td({-class=>'synonms'}, $row->[6]),
				$prow,
				#td({-class=>'synopay'}, $row->[9]),
				td({-class=>'synopub'}, $row->[7])
			);
		}
		
		if ($dbase ne 'flow' and $dbase ne 'flow2' and $dbase ne 'cerambycidae' ) {
			$content .= Tr(td({-style=>'height: 20px;'})) . Tr({-class=>'synodiv'},
				td({-class=>'synofam'}, b($trans->{'total'}->{$lang})),
				td({-class=>'synogen'}, b($counts->[0])),
				td({-class=>'synospc'}, b($counts->[1])),
				td({-class=>'synonms'}, b($counts->[2])),
				$ptot,
				#td({-class=>'synopay'}, b($counts->[4])),
				td({-class=>'synopub'}, b($pub_numb->[0]))
			);
		}
		my $maj;
		if ($dbase ne 'cerambycidae') {
			$maj = 		div({-class=>'synodiv'},
						$trans->{'dmaj'}->{$lang}." : $last ",
						a({-class=>'exploa', -style=>'margin-left: 25px;', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=makeboard"}, 
						"$trans->{'uptodate'}->{$lang}")
					);

		}
		
	 	$fullhtml =   	div({-class=>'explocontent'},
					div({-class=>'navup'}, 
						$totop
					),
					$prevnext,
					h2({-class=>'exploh2', -id=>'boardtitle'}, $trans->{"board"}->{$lang}),
					table({-class=>'boardtable'}, $content),
					br,
					$maj,
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
sub family_card {
	if ( my $dbc = db_connection($config) ) { 
		my $family_id = $id;
		my $fam_name;

		# Fetch the family name
		my $name = request_row("SELECT t.index, n.orthographe, n.autorite, n.ref_publication_princeps, ni.page_princeps, d.url, d.logo_url
			FROM taxons AS t 
			LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
			LEFT JOIN taxons_x_documents AS txd ON t.index = txd.ref_taxon
			LEFT JOIN documents AS d ON d.index = txd.ref_document
			LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
			LEFT JOIN noms AS ni ON n.index = ni.index
			LEFT JOIN rangs AS r ON t.ref_rang = r.index
			LEFT JOIN statuts AS s ON txn.ref_statut = s.index
			WHERE s.en = 'valid' 
			AND (d.type = 'key' OR d.type IS NULL)
			AND t.index = $family_id;",$dbc);
		
		if ($name->[5]) { 
			if ($name->[6]) { $name->[6] = '&nbsp;' . img({-src=>$name->[6], -style=>'width: 14px; border: 0; margin: 0; padding: 0;'}); }
			$name->[5] = a({-class=>'exploa', -style=>'margin-left: 20px;', -href=>$name->[5], -target=>'_blank'}, $name->[6] . " $trans->{'id_key'}->{$lang} "); 
		}
		
		$fam_name = i("$name->[1]") . " $name->[2]" . $name->[5];

		my $display;
		my $publication_tab;
		if ( $name->[3] ) {
			#if ($name->[4]) { 
			#	$display .= $fam_name . $trans->{'DescriptNewFm'}->{$lang} . " $trans->{'dansin'}->{$lang} " .  publication($name->[3], 0, 1, $dbc ) . ": $name->[4]" . p;
			#}
			$publication_tab = h4({-class=>'exploh4'}, $trans->{'ori_pub'}->{$lang});
			my $pub = pub_formating($name->[3], $dbc, $name->[4] );
			$publication_tab .= div({-class=>'pubdiv'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$name->[3]"}, "$pub") . getPDF($name->[3]));
		}
		else {
			#$publication_tab = div({-class=>'subject'}, $trans->{"UNK"}->{$lang});
		}
		
		# Fetch previous and next family in the global family list
		my ( $previous_id, $prev_name, $prev_autority, $next_id, $next_name, $next_autority, $stop, $current_id, $current_name, $current_authority );
		
		$dbc->{RaiseError} = 1;
		my $sth = $dbc->prepare( "SELECT t.index, nc.orthographe, nc.autorite
						FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
						LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
						LEFT JOIN noms AS n ON txn.ref_nom = n.index
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						LEFT JOIN rangs AS r ON t.ref_rang = r.index
						WHERE r.en = 'family' AND s.en = 'valid'
						ORDER BY LOWER ( n.orthographe ), nc.orthographe;" );
		$sth->execute( );
		$sth->bind_columns( \( $current_id, $current_name, $current_authority ) );
		while ( $sth->fetch() ){
			if ( $stop ){
				( $next_id, $next_name, $next_autority ) = ( $current_id, $current_name, $current_authority );
				last;
			}
			else {
				if ( $current_id == $family_id ){
					$stop = 1;
				}
				else {
					( $previous_id, $prev_name, $prev_autority ) = ( $current_id, $current_name, $current_authority );
				}
			}
		}
		$sth->finish();

		my $up;
		if ($dbase ne 'cool' and $dbase ne 'flow' and $dbase ne 'flow2' and $dbase ne 'strepsiptera') {
		 	$up = 	div({-class=>'navup'}, $totop . ' > ' . makeup('families', $trans->{'families'}->{$lang}));
		}
			
		#$up .= prev_next_card( $card, $previous_id, i($prev_name) . " $prev_autority", $next_id, i($next_name) ." $next_autority" );

		# Fetch species classified in this family
		my $ranks_ids = get_rank_ids( $dbc );
		
		my $fam_taxa;
		my $sf_tab;
		my $sps = 0;
		my $ge_ids  = [];
		my $sp_ids  = [];
		my @spids;
				
		if (url_param('mode') eq 'genera types') {
			$ge_ids = son_taxa($family_id, $ranks_ids->{"genus"}->{"index"}, $dbc);

			if ( scalar @{$ge_ids} ){
			
				my $gids = "(" . join(',', @{$ge_ids}) . ")";
				my ( $genusid, $genusname, $genusautority, $page );
				$sth = $dbc->prepare( "SELECT t.index, nc.orthographe, nc.autorite, n.page_princeps FROM taxons AS t
							LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
							LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
							LEFT JOIN noms AS n ON n.index = nc.index
							LEFT JOIN rangs AS r ON t.ref_rang = r.index
							LEFT JOIN statuts AS s ON txn.ref_statut = s.index
							WHERE s.en = 'valid' AND t.index IN $gids
							ORDER BY n.orthographe;" );
				$sth->execute( );
				$sth->bind_columns( \( $genusid, $genusname, $genusautority, $page ) );
				
				$fam_taxa .= start_ul({-class=>'exploul'});
				while ( $sth->fetch() ){
					$page = $page ? ": $page" : $page;
					
					$fam_taxa .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=genus&id=$genusid"}, i("$genusname") . " $genusautority$page"));
					
					my $synonyms = request_tab("	SELECT distinct nc.orthographe, nc.autorite, n.page_princeps, s.$lang
									FROM noms_complets AS nc
									LEFT JOIN noms AS n ON n.index = nc.index
									LEFT JOIN taxons_x_noms AS txn ON nc.index = txn.ref_nom
									LEFT JOIN statuts AS s ON txn.ref_statut = s.index
									WHERE s.en in ('nomen praeoccupatum','nomen nudum','synonym','nomen oblitum','previous rank', 'objective synonym')
									AND txn.ref_taxon = $genusid;",$dbc);
					
					foreach my $syn (@{$synonyms}) {
						if ($syn->[0] ne $genusname) {
							$syn->[2] = $syn->[2] ? ": ".$syn->[2] : $syn->[2];
							$fam_taxa .= li({-class=>'exploli'}, "= ". i($syn->[0]) . " " . $syn->[1] . $syn->[2] . " " . span({-style=>'color: #444444'}, $syn->[3]) );
						}
					}

					my $sp_ids = son_taxa($genusid, $ranks_ids->{"species"}->{"index"}, $dbc);
			
					if ( scalar @{$sp_ids} ){
						my $ids = "(" . join(',', @{$sp_ids}) . ")";
					
						my ( $speciesid, $nameid, $speciesname, $speciesautority, $page_princeps, $brack );
						my $sth2 = $dbc->prepare( "SELECT t.index, nc.index, nc.orthographe, nc.autorite, n.page_princeps, n.parentheses FROM taxons AS t 
									LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
									LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
									LEFT JOIN noms AS n ON n.index = nc.index
									LEFT JOIN rangs AS r ON t.ref_rang = r.index
									LEFT JOIN statuts AS s ON txn.ref_statut = s.index
									WHERE s.en = 'valid'
									AND t.index IN $ids
									AND n.gen_type = 't'
									AND ( nc.orthographe NOT LIKE '%(%' OR nc.orthographe LIKE '%$genusname%$genusname%' )
									ORDER BY n.orthographe;" );
						$sth2->execute( );
						$sth2->bind_columns( \( $speciesid, $nameid, $speciesname, $speciesautority, $page_princeps, $brack ) );
					
						while ( $sth2->fetch() ){
							my $req = "	SELECT nc.orthographe, nc.autorite, n.page_princeps
											FROM noms_complets AS nc
											LEFT JOIN noms AS n ON n.index = nc.index
											LEFT JOIN taxons_x_noms AS txn ON nc.index = txn.ref_nom
											LEFT JOIN statuts AS s ON txn.ref_statut = s.index
											WHERE txn.ref_taxon = $speciesid
											AND s.en not in ('valid', 'correct use', 'misidentification', 'prevous identification')
											AND n.gen_type = 't';";
							
							my $original = request_tab($req, $dbc);
							
							#if ($genusname eq '') { $fam_taxa .= $req; }
							
							if ($original->[0][0]) {
								$speciesname = $original->[0][0]; $speciesautority = $original->[0][1]; $page_princeps = $original->[0][2];
							}
							else {
								my $conditions;
								$conditions = $brack ? "from 2 for length('$speciesautority')-2" : "from 1 for length('$speciesautority')";
							
								$original = request_tab("	SELECT nc.orthographe, nc.autorite, n.page_princeps
												FROM noms_complets AS nc
												LEFT JOIN noms AS n ON n.index = nc.index
												LEFT JOIN taxons_x_noms AS txn ON nc.index = txn.ref_nom
												LEFT JOIN statuts AS s ON txn.ref_statut = s.index
												WHERE txn.ref_taxon = $speciesid
												AND s.en = 'previous combination'
												AND nc.autorite = substring('$speciesautority' $conditions);",$dbc);
							
								if ($original->[0][0]) { $speciesname = $original->[0][0]; $speciesautority = $original->[0][1]; $page_princeps = $original->[0][2]; }
							}
							$page_princeps = $page_princeps ? ": $page_princeps" : $page_princeps;
							$fam_taxa .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$speciesid"}, '&nbsp;&nbsp;&nbsp;&nbsp;' . i("$speciesname") . " $speciesautority$page_princeps " . span({-style=>'color: red'}, "&nbsp;  $trans->{'typespe'}->{$lang}" . p)));
							$sps++;
						}
						$sth2->finish();
					}
				}
				$sth->finish();
				$fam_taxa .= end_ul();
				
				$fam_taxa = 	br.h3({-class=>'exploh3', -style=>'display: inline;'}, scalar @{$ge_ids} . " $trans->{'genus(s)'}->{$lang}"). p.
						#h3({-class=>'exploh3', -style=>'display: inline;'}, " $sps $trans->{'species(s)'}->{$lang}"). p.
						$fam_taxa;
			}
			else {
				#$fam_taxa = ul({-class=>'exploul'}, li({-class=>'exploli'}, $trans->{"UNK"}->{$lang}));
			}
		}
		else {	
			my $sf_ids = son_taxa($family_id, $ranks_ids->{"subfamily"}->{"index"}, $dbc);
			if ( scalar @{$sf_ids} ){
				my $ids = "(";
				map { $ids .= "$_,"} @{$sf_ids};
				$ids =~ s/,$/)/;
				my $sf_list = request_tab("	SELECT t.index, n.orthographe, n.autorite 
								FROM taxons AS t 
								LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
								LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
								LEFT JOIN rangs AS r ON t.ref_rang = r.index
								LEFT JOIN statuts AS s ON txn.ref_statut = s.index
								WHERE s.en = 'valid' AND t.index IN $ids
								ORDER BY LOWER ( n.orthographe );",$dbc);
	
				if (scalar(@{$sf_list})) { 
					
					if (scalar(@{$sf_list}) == 1) { 
						$sf_tab .= h4({-class=>'exploh4'}, scalar @{$sf_list} . " ". ucfirst($trans->{'subfamily'}->{$lang})); 
					}
					else {
						$sf_tab .= h4({-class=>'exploh4'}, scalar @{$sf_list} . " ". ucfirst($trans->{'subfamilies'}->{$lang})); 
					}
					$sf_tab .= start_ul({-class=>'exploul'});
					foreach my $sf ( @{$sf_list} ){
						#$sf_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=subfamily&id=$sf->[0]"}, i("$sf->[1]") . " $sf->[2]" ) );
						$sf_tab .= li({-class=>'exploli'}, i("$sf->[1]") . " $sf->[2]" );
					}
					$sf_tab .= end_ul();
				}
			}
			
			$ge_ids = son_fulltaxa($family_id, $ranks_ids->{"genus"}->{"index"}, $dbc);	
			#$sp_ids = son_fulltaxa($family_id, $ranks_ids->{"species"}->{"index"}, $dbc);
						
			if (scalar @{$ge_ids}) {
			
				#$fam_taxa .= start_ul({-class=>'exploul'});
				my $test = 0;
				foreach (@{$ge_ids}) {
					#if ($_->[3]) { $test = 1; $_->[3] = a({-class=>'exploa', -style=>'margin-left: 20px;', -href=>$_->[3], -target=>'_blank'}, " $trans->{'id_key'}->{$lang} "); }
					#$fam_taxa .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=genus&id=$_->[0]"}, i($_->[1]) . " " . $_->[2] . $_->[3] ));	
					my ($sfname) = @{ request_row("SELECT parent_taxon_name((SELECT ref_taxon_parent FROM taxons WHERE index = $_->[0]), 'subfamily')", $dbc)};
					if ($sfname) { $sfname = "&nbsp; ($sfname)"; }
					if ($_->[3]) { $test = 1; $_->[3] = a({-class=>'exploa', -style=>'margin-left: 20px;', -href=>$_->[3], -target=>'_blank'}, img({-src=>"/explorerdocs/icon-fiche.png", -style=>'border: 0; margin: 0;'})); }					
					$fam_taxa .= Tr(td({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=genus&id=$_->[0]"}, i($_->[1]) . " " . $_->[2]) . $sfname), td({-style=>'text-align: center;'}, $_->[3]));	
				}
				
				if ($test) { $fam_taxa = Tr(td(h3({-class=>'exploh3'}, scalar @{$ge_ids} . " $trans->{'genus(s)'}->{$lang}")), td(h3({-class=>'exploh3', -style=>'font-size: 12px;'}, $trans->{'morphcards'}->{$lang}))) . $fam_taxa; }
				else { $fam_taxa = Tr(td({-colspan=>2}, h3({-class=>'exploh3'}, scalar @{$ge_ids} . " $trans->{'genus(s)'}->{$lang}"))) . $fam_taxa; }
				$test = 0;
				my $fam_sptaxa;
				if (scalar @{$sp_ids}) {
					#if ($_->[3]) { $test = 1; $_->[3] = a({-class=>'exploa', -style=>'margin-left: 20px;', -href=>$_->[3], -target=>'_blank'}, " $trans->{'id_key'}->{$lang} "); }
					#$fam_taxa .= end_ul();
					$fam_sptaxa .= Tr(td({-colspan=>2}, h3({-class=>'exploh3'}, br . scalar @{$sp_ids} . " $trans->{'species(s)'}->{$lang}")));
					#$fam_taxa .= start_ul({-class=>'exploul'});
					foreach (@{$sp_ids}) {
						if ($_->[0]%2 == 1) { push(@spids, $_->[0]); }
						#$fam_taxa .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$_->[0]"}, i($_->[1]) . " $_->[2]" ));
						$fam_sptaxa .= Tr(td({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$_->[0]"}, i($_->[1]) . " $_->[2]")), td($_->[3]));
					}
					#if ($test) { $fam_sptaxa = Tr(td(h3({-class=>'exploh3'}, scalar @{$ge_ids} . " $trans->{'species(s)'}->{$lang}")), td(h3({-class=>'exploh3', -style=>'font-size: 12px;'}, $trans->{'morphcards'}->{$lang}))) . $fam_sptaxa; }
					#else { $fam_sptaxa = Tr(td({-colspan=>2}, h3({-class=>'exploh3'}, scalar @{$ge_ids} . "$trans->{'species(s)'}->{$lang}"))) . $fam_sptaxa; }
				}
				#$fam_taxa .= end_ul();
				$fam_taxa = table({-style=>'margin-top: 10px; border: 0px darkgreen solid;'}, $fam_taxa, $fam_sptaxa);
			}
			else {
				#$fam_taxa = ul({-class=>'exploul'}, li({-class=>'exploli'}, $trans->{"UNK"}->{$lang}));
			}
		}
				
		my $map;
		my @countries;
		if ($dbase eq 'flow' or $dbase eq 'flow2' or url_param('mode') eq 'full' or $mode eq 'full') {
			
			my %tgdone;
			my @tdwg4;
			my $areas;
			my %level1;
			my $values = scalar(@spids) ? join(', ', @spids) . ', ' : undef;

			my $sth5 = $dbc->prepare( "	SELECT DISTINCT p.tdwg, p.en, p.parent, p.$lang, p.index
							FROM taxons_x_pays AS txp 
							LEFT JOIN pays AS p ON txp.ref_pays = p.index 
							WHERE txp.ref_taxon IN ($values $family_id) and p.en != 'Unknown' 
							ORDER BY p.$lang;" );
			
			$sth5->execute( );
			my ( $tdwg, $en, $parent, $country, $country_id );
			$sth5->bind_columns( \( $tdwg, $en, $parent, $country, $country_id ) );
			while ( $sth5->fetch ) {

				unless (exists $tgdone{$tdwg.'/'.$en}) {
					
					my @fathers;
					
					if (length($tdwg) >= 5) { 
						
						if ($parent) {
							my ($father) = request_row("SELECT en FROM pays WHERE tdwg = '$parent';",$dbc,1);
							if ($father eq $en) { push(@fathers, $parent) }
							else { push(@tdwg4, $tdwg); }
						}
						else {
							push(@tdwg4, $tdwg);
						}
					} else {
						push(@fathers, $tdwg);
					}
					
					while (scalar(@fathers)) {
						my $sons = request_tab("SELECT tdwg FROM pays WHERE parent IN ('" . join("', '",@fathers) . "');",$dbc,1);
						
						@fathers = ();
						
						if (scalar(@{$sons})) {
							foreach (@{$sons}) {
								if (length($_) >= 5) { 
									push(@tdwg4, $_); 
								}
								else { push(@fathers, $_); }
							}
						}
					}
					$tgdone{$tdwg.'/'.$en} = 1;
					my @tmp = ($country_id, $country);
					push(@countries, \@tmp);
				}
			}
			
			my $bgsea;
			my $bgearth;
			my $cclr;
			my $wdth;
			
			if ($dbase eq 'psylles') { 
				$bgsea = '000000';
				$bgearth = '282828';
				$cclr = '99dd44';
				$wdth = 700 
			}
			elsif ($dbase eq 'cool') { 
				$bgsea = '8D1610';
				$bgearth = '650C06';
				$cclr = 'FFCC66';
				$wdth = 500 
			}
			elsif ($dbase eq 'flow' or $dbase eq 'flow2') { 
				$bgsea = '';
				$bgearth = 'BBBBBB';
				$cclr = '000066';
				$wdth = 470 
			}
			else { 
				$bgsea = '';
				$bgearth = 'CCCCCC';
				$cclr = '0F5286';
				$wdth = 800 
			}
			
			$areas = 'ad=';
			my $mapok;
			if (scalar(@tdwg4)) {
				$areas .= 'tdwg4:a:'.join(',', @tdwg4).'||';
				$mapok = 1;
			}
			if (scalar(keys(%level1)) == 0) {
				$areas .= "tdwg1:b:1,2,3,4,5,6,7,8,9";
			}
			else {
				my ($key) = keys(%level1);
				if ($key == 6) { $mapok = 0; }
				$areas .= "tdwg1:b:$key";
			}
			
			my $styles = "as=a:$cclr,$cclr,0|b:$bgearth,$bgearth,0";
			
			if ($mapok) {
				$map = "<script type='text/javascript'>
				function ImageMax(chemin) {
					var html = '<html> <head> <title>Distribution</title> </head> <body style=\"background: #$bgsea;\"><IMG style=\"background: #$bgsea;\" src='+chemin+' BORDER=0 NAME=ImageMax></body></html>';
					var popupImage = window.open('','_blank','toolbar=0, location=0, scrollbars=0, directories=0, status=0, resizable=1, width=1020, height=520');
					popupImage.document.open();
					popupImage.document.write(html);
					popupImage.document.close()
				};
				</script>
					<img id='cmap' style='background: #$bgsea;' src='$maprest?$areas&$styles&ms=$wdth' onMouseOver=\"this.style.cursor='pointer';\"  onclick=\"ImageMax($maprest?$areas&$styles&ms=1000');\">". br. br;
			}
		}
		
		my $countries_list;
		if ( scalar(@countries) ){
			
			$countries_list =   table({-style=>'border: 0px solid black;'},
						Tr(
							td({-style=>'width: 16px; vertical-align: middle; border: 0px solid black;'},
								span({	-id=>'ctrdisp',
									-class=>'disparrow',
									-style=>'display: block;',
									-onMouseOver=>  "document.getElementById('ctrdisp').style.cursor = 'pointer';",
									-onClick=>"	document.getElementById('ctrdisp').style.display = 'none';
											document.getElementById('ctrhide').style.display = 'block';
											document.getElementById('paysCell').style.display = 'table-cell';"}, ''),
								span({	-id=>'ctrhide',
									-class=>'hidearrow',
									-style=>'display: none;',
									-onMouseOver=>  "document.getElementById('ctrhide').style.cursor = 'pointer';",
									-onClick=>"	document.getElementById('ctrhide').style.display = 'none';
											document.getElementById('ctrdisp').style.display = 'block';
											document.getElementById('paysCell').style.display = 'none';"}, '')
							),
							td({-style=>'vertical-align: middle; border: 0px solid black;'},
								h4({	-class=>'exploh4',	
									-id=>'cttitle',
									-onMouseOver=>  "this.style.cursor = 'pointer';",
									-onClick=>"	if (document.getElementById('paysCell').style.display == 'table-cell') {
												document.getElementById('ctrhide').style.display = 'none';
												document.getElementById('ctrdisp').style.display = 'block';
												document.getElementById('paysCell').style.display = 'none';
											}
											else{
												document.getElementById('ctrdisp').style.display = 'none';
												document.getElementById('ctrhide').style.display = 'block';
												document.getElementById('paysCell').style.display = 'table-cell';
											}"}, 
											$trans->{"geodistribution"}->{$lang})
							)
						),
						Tr(
							td({-colspan=>2, -id=>'paysCell', -style=>'display: none; border: 0px solid black;'},
								ul({-class=>'exploul'},  
									join('', map { 
										li({-class=>'countriesLi'}, 
											a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=$_->[0]"."XX"."$name->[4]"}, $_->[1] )); 
										} sort {$a->[1] cmp $b->[1]} @countries 
									)
								)
							)
						),
						Tr(td({-colspan=>2}, $map))
					);
		}
		
		my $vdisplay = get_vernaculars($dbc, 'txv.ref_taxon', $family_id);
		
		my $synss = request_tab(	"SELECT nc.index,
							nc.orthographe, 
							nc.autorite, 
							s.$lang, 
							txn.ref_publication_utilisant, 
							txn.ref_publication_denonciation, 
							s.en, 
							nc2.orthographe, 
							nc2.autorite,
							txn.page_utilisant,
							txn.page_denonciation
						FROM taxons_x_noms AS txn 
						LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
						LEFT JOIN noms_complets AS nc2 ON nc2.index = txn.ref_nom_cible
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index 
						LEFT JOIN noms AS n ON txn.ref_nom = n.index
						LEFT JOIN publications As pubd ON pubd.index = txn.ref_publication_denonciation
						LEFT JOIN publications As pubu ON pubu.index = txn.ref_publication_utilisant
						WHERE txn.ref_taxon = $family_id 
						AND s.en not in ('valid', 'dead end') 
						ORDER BY n.annee, n.parentheses, pubu.annee, pubd.annee;",$dbc);
					

		my $synonyms;
		my $uses;
		foreach my $syn ( @{$synss} ){
						
			if ( $syn->[6] eq 'synonym' ){
				my @pub_den;
				if ($syn->[5]) { @pub_den = publication($syn->[5], 0, 1, $dbc ); }
				my $sl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$sl .= " $syn->[3] $trans->{'of'}->{$lang} " . i($syn->[7]) . " $syn->[8]";
				if ($pub_den[1]) {
					my $page;
					if ($syn->[10]) { $page = ": $syn->[10]" }
					$sl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$sl .= getPDF($syn->[5]);
				}
				$synonyms .= li({-class=>'exploli'}, $sl);
			}
			elsif ( $syn->[6] eq 'correct use' or $syn->[6] eq 'wrong spelling' ){
				my @pub_use;
				if ($syn->[4]) { @pub_use = publication($syn->[4], 0, 1, $dbc ); }
				my @pub_den;
				if ($syn->[5]) { @pub_den = publication($syn->[5], 0, 1, $dbc ); }
				my $sl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				if ($pub_use[1]) {
					my $page;
					if ($syn->[9]) { $page = ": $syn->[9]" }
					$sl .= " $trans->{'cited_in'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" );
					$sl .= getPDF($syn->[4]);
				}
				if ($pub_den[1]) {
					my $page;
					if ($syn->[10]) { $page = ": $syn->[10]" }
					$sl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$sl .= getPDF($syn->[5]);
				}
				$uses .= li({-class=>'exploli'}, $sl);
			}
		}		
		if ($synonyms) { $synonyms =  h4({-class=>'exploh4'}, ucfirst($trans->{'synonymie'}->{$lang})) . ul({-class=>'exploul'}, $synonyms); }
		if ($uses) { $uses =  h4({-class=>'exploh4'}, ucfirst($trans->{'Chresonym(s)'}->{$lang})) . ul({-class=>'exploul'}, $uses); }


		$fullhtml =  	div({-class=>'explocontent'},
					$up,
					div({-class=>'carddiv'},
						table({-style=>'border: 0px navy solid;'},
							Tr(
								td(
									h2({-class=>'exploh2'}, "$trans->{'family'}->{$lang}"),
									div({-class=>'subject'}, "$fam_name"),
									$publication_tab,
									$display,
									$synonyms,
									$uses,
									$sf_tab,
									$fam_taxa,
									$vdisplay
								),
								td({-style=>'vertical-align: top;'},
									$countries_list
								)							)
						)
					)
				);
				
		print $fullhtml;

		$dbc->disconnect;
	}

	else {}
}

sub get_vernaculars {
	
	my ($dbc, $field, $index) = @_;
	
	# fetching vernacular names
	my $req = "SELECT nv.index, nom, l.langage, p.en, txv.ref_pub, nv.ref_pays FROM taxons_x_vernaculaires AS txv 
			LEFT JOIN noms_vernaculaires AS nv ON nv.index = txv.ref_nom 
			LEFT JOIN langages as l ON l.index = nv.ref_langage 
			LEFT JOIN pays as p ON p.index = nv.ref_pays
			LEFT JOIN publications AS pb ON txv.ref_pub = pb.index
			WHERE $field = $index
			ORDER BY nom, pb.annee;";

	my $vernaculars = request_tab($req, $dbc);
	my $vdisplay;
	if (scalar @{$vernaculars}) {
			
		my %verns;
		my @order;
		foreach (@{$vernaculars}) {
			my @pub;
			if ($_->[4]) {
				@pub = publication($_->[4], 0, 1, $dbc);
			}				
			
			unless (exists $verns{$_->[0]}) { 
				push(@order, $_->[0]);
				$verns{$_->[0]} = {};
				$verns{$_->[0]}{'label'} = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=vernacular&id=$_->[0]"}, $_->[1] );
				if ($_->[3]) { $verns{$_->[0]}{'label'} .= " in " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=$_->[5]"}, $_->[3]); }
				$verns{$_->[0]}{'label'} .= " (" . $_->[2] . ")";
				
				$verns{$_->[0]}{'refs'} = ();
			}
			
			if (scalar @pub) {
				push(@{$verns{$_->[0]}{'refs'}}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$_->[4]"}, "$pub[1]" ) . getPDF($_->[4]));
			}
		}
				
		foreach (@order) {
			my $list = $verns{$_}{'label'};
			if ($verns{$_}{'refs'}) { $list .= ' according to ' . join (', ', @{$verns{$_}{'refs'}}); }
			$vdisplay .= li({-class=>'exploli'}, $list);
		}
		
		$vdisplay = h4({-class=>'exploh4'}, $trans->{'vernacular(s)'}->{$lang}) . ul({-class=>'exploul'}, $vdisplay) . p;
	}
	
	return $vdisplay;
}

# Genus card
#################################################################
sub genus_card {
	if ( my $dbc = db_connection($config) ) {
		my $genus_id = $id;
		my $ge_name;
		my $ge_tab;
		my $display;

		my ($family_fullname) = @{ request_row("SELECT parent_taxon_fullname((SELECT ref_taxon_parent FROM taxons WHERE index = $genus_id), 'family')", $dbc)};
		my ($family_id) = @{ request_row("SELECT parent_taxon_id((SELECT ref_taxon_parent FROM taxons WHERE index = $genus_id), 'family')", $dbc)};

		my $name = request_row("SELECT 	t.index, 
								n.orthographe, 
								n.autorite, 
								n.ref_publication_princeps, 
								n.index, 
								page_princeps
							FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
							LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
							LEFT JOIN noms AS ni ON ni.index = n.index
							LEFT JOIN rangs AS r ON t.ref_rang = r.index
							LEFT JOIN statuts AS s ON txn.ref_statut = s.index
							WHERE s.en = 'valid' AND ref_taxon = $genus_id;",$dbc);

		$ge_tab = i("$name->[1]") . " $name->[2]";
		$ge_name = "$name->[1] $name->[2]";

		my ( $previous_id, $prev_name, $prev_autority, $next_id, $next_name, $next_autority, $stop, $current_id, $current_name, $current_authority );
		$dbc->{RaiseError} = 1;
		
		my $sth2 = $dbc->prepare( "	SELECT 	t.index, 
							nc.orthographe, 
							nc.autorite
						FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
						LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
						LEFT JOIN noms AS n ON txn.ref_nom = n.index
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						LEFT JOIN rangs AS r ON t.ref_rang = r.index
						WHERE r.en = 'genus' AND s.en = 'valid'
						ORDER BY LOWER ( n.orthographe ), nc.orthographe;" );
		$sth2->execute( );
		$sth2->bind_columns( \( $current_id, $current_name, $current_authority ) );
		while ( $sth2->fetch() ){
			if ( $stop ){
				( $next_id, $next_name, $next_autority ) = ( $current_id, $current_name, $current_authority );
				last;
			}
			else {
				if ( $current_id == $genus_id ){
					$stop = 1;
				}
				else {
					( $previous_id, $prev_name, $prev_autority ) = ( $current_id, $current_name, $current_authority );
				}
			}
		}
		$sth2->finish();

		my $up;
		if ($dbase ne 'cool' and $dbase ne 'flow' and $dbase ne 'flow2' and $dbase ne 'strepsiptera') {
			$up = 	div({-class=>'navup'}, 
					$totop, span({-class=>'navarrow'},' > '),
					makeup('genera', $trans->{'genus(s)'}->{$lang}, lc(substr($ge_name, 0, 1)))
				);
		}
			
		#$up .= prev_next_card( $card, $previous_id, i($prev_name) . " $prev_autority", $next_id, i($next_name) ." $next_autority" );

		my $publication_tab;
		if ( $name->[3] ) {
			#if ($name->[5]) { 
			#	$display .= li({-class=>'exploli'}, $ge_tab . " " . $trans->{'DescriptNewGr'}->{$lang} . " $trans->{'dansin'}->{$lang} " .  publication($name->[3], 0, 1, $dbc ) . ": $name->[5]");
			#}
			$publication_tab = h4({-class=>'exploh4'}, $trans->{'ori_pub'}->{$lang}); 
			my $pub = pub_formating($name->[3], $dbc, $name->[5] );
			$publication_tab .= div({-class=>'pubdiv'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$name->[3]"}, "$pub") . getPDF($name->[3]));
		}
		else {
			#$publication_tab = div({-class=>'pubdiv'}, $trans->{"UNK"}->{$lang});
		}

		my $ranks_ids = get_rank_ids( $dbc );
		my $sg_tab;
		my $sg_ids = son_taxa($genus_id, $ranks_ids->{"subgenus"}->{"index"}, $dbc);
		if ( scalar @{$sg_ids} ){
			my $ids = "(";
			map { $ids .= "$_,"} @{$sg_ids};
			$ids =~ s/,$/)/;
			my $sg_list = request_tab("	SELECT t.index, n.orthographe, n.autorite 
							FROM taxons AS t 
							LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
							LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
							LEFT JOIN rangs AS r ON t.ref_rang = r.index
							LEFT JOIN statuts AS s ON txn.ref_statut = s.index
							WHERE s.en = 'valid' AND t.index IN $ids
							ORDER BY LOWER ( n.orthographe );",$dbc);

			if (scalar(@{$sg_list})) { 
				
				if (scalar(@{$sg_list}) == 1) { 
					$sg_tab .= h4({-class=>'exploh4'}, scalar @{$sg_list} . " ". ucfirst($trans->{'subgenus'}->{$lang})); 
				}
				else {
					$sg_tab .= h4({-class=>'exploh4'}, scalar @{$sg_list} . " ". ucfirst($trans->{'subgenus(s)'}->{$lang})); 
				}
				$sg_tab .= start_ul({-class=>'exploul'});
				foreach my $sg ( @{$sg_list} ){
					$sg_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=subgenus&id=$sg->[0]"}, i("$sg->[1]") . " $sg->[2]" ) );
				}
				$sg_tab .= end_ul();
			}
		}

		my $sp_tab;
		my $sp_ids = son_taxa($genus_id, $ranks_ids->{"species"}->{"index"}, $dbc);
		if ( scalar @{$sp_ids} ){
			my $ids = "(";
			map { $ids .= "$_,"} @{$sp_ids};
			$ids =~ s/,$/)/;
			my $sp_list = request_tab("	SELECT t.index, nc.orthographe, nc.autorite, nc.gen_type FROM taxons AS t 
							LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
							LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
							LEFT JOIN noms AS n ON n.index = nc.index
							LEFT JOIN rangs AS r ON t.ref_rang = r.index
							LEFT JOIN statuts AS s ON txn.ref_statut = s.index
							WHERE s.en = 'valid' AND t.index IN $ids
							ORDER BY LOWER ( nc.orthographe );",$dbc);

			if (scalar(@{$sp_list})) { 
				
				$sp_tab .= h4({-class=>'exploh4'}, scalar @{$sp_list} . " $trans->{'species(s)'}->{$lang}");
				$sp_tab .= start_ul({-class=>'exploul'});

				foreach my $sp ( @{$sp_list} ){
					my $typestr;
					if ($sp->[3]) { $typestr = span({-style=>'color: red'}, "&nbsp;  $trans->{'typespe'}->{$lang}") }
					$sp_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$sp->[0]"}, i("$sp->[1]") . " $sp->[2] $typestr" ) );
				}
				$sp_tab .= end_ul();
			}
		}
                
		my $synss = request_tab(	"SELECT nc.index,
							nc.orthographe, 
							nc.autorite, 
							s.$lang, 
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
							s.en, 
							nc2.orthographe, 
							nc2.autorite,
							txn.page_utilisant,
							txn.page_denonciation
						FROM taxons_x_noms AS txn 
						LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
						LEFT JOIN noms_complets AS nc2 ON nc2.index = txn.ref_nom_cible
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index 
						LEFT JOIN noms AS n ON txn.ref_nom = n.index
						LEFT JOIN publications As pubd ON pubd.index = txn.ref_publication_denonciation
						LEFT JOIN publications As pubu ON pubu.index = txn.ref_publication_utilisant
						WHERE txn.ref_taxon = $genus_id 
						AND s.en not in ('valid', 'dead end') 
						ORDER BY n.annee, n.parentheses, pubu.annee, pubd.annee;",$dbc);


		my ( $syn_list, $typos_list, $combi_list, $wid_list, $os_list, $ios_list, $ies_list, $pid_list, $em_list, $ch_list, $hom_list, $nn_list, $np_list, $uk_list );
		my $modal= 1;
		my $nomstat;
		my %chres;
		my $ch_tab;
			
		foreach my $syn ( @{$synss} ){
						
			if ( $syn->[15] eq 'synonym' or $syn->[15] eq 'junior synonym' ){
				#my $ambiguous = synonymy( $syn->[6], $syn->[8], $syn->[10] );
				#my $complete = completeness( $syn->[7], $syn->[9], $syn->[11] );
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $sl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$sl .= " $syn->[3] $trans->{'of'}->{$lang} " . i($syn->[16]) . " $syn->[17]";
				if ($pub_den[1]) {
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$sl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$sl .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $sl) }
				elsif ($modal == 2) { $syn_list .= li({-class=>'exploli'}, $sl) }
			}
			elsif ( $syn->[15] eq 'wrong spelling' ){
				my @pub_use = publication($syn->[4], 0, 1, $dbc );
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $wsl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$wsl .= " $syn->[3] $trans->{'of'}->{$lang} " . i($syn->[16]) . " $syn->[17]";
				if ($pub_use[1]) { 
					my $page;
					if ($syn->[18]) { $page = ": $syn->[18]" }
					$wsl .= " $trans->{'dansin'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" );
					$wsl .= getPDF($syn->[4]);
				}
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$wsl .= " $trans->{'corrby'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$wsl .= getPDF($syn->[5]);
				}
				if ($modal == 1) { 
					#$display .= li({-class=>'exploli'}, $wsl);
					$chres{$syn->[0].$syn->[4].$syn->[20]}{'label'} = $wsl;
				}
				elsif ($modal == 2) { $typos_list .= li({-class=>'exploli'}, $wsl) }
			}
			elsif ( $syn->[15] eq 'previous combination' ){
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $tl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]");
				$tl .= " $syn->[3] $trans->{'of'}->{$lang} " . i($syn->[16]) . " $syn->[17]";
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$tl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$tl .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $tl) }
				elsif ($modal == 2) { $combi_list .= li({-class=>'exploli'}, $tl) }
			}
			elsif ( $syn->[15] eq 'misidentification' ){
				my @pub_use = publication($syn->[4], 0, 1, $dbc );
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $mil .= a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2] $syn->[3]" );
				if ($pub_use[1]) { 
					my $page;
					if ($syn->[18]) { $page = ": $syn->[18]" }
					$mil .= " $trans->{'dansin'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" );
					$mil .= getPDF($syn->[4]);
				}
				if ($pub_den[1]) {
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$mil .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$mil .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $mil) }
				elsif ($modal == 2) { $wid_list .= li({-class=>'exploli'}, $mil) }
			}
			elsif ( $syn->[15] eq 'previous identification' ){
			
				my @pub_use = publication($syn->[4], 0, 1, $dbc );
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $pil .= a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$pil .= " $trans->{'misid'}->{$lang} $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
				if ($pub_use[1]) { 
					my $page;
					if ($syn->[18]) { $page = ": $syn->[18]" }
					$pil .= " $trans->{'dansin'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" );
					$pil .= getPDF($syn->[4]);
				}
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$pil .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$pil .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $pil) }
				elsif ($modal == 2) { $pid_list .= li({-class=>'exploli'}, $pil) }
			}
			elsif ( $syn->[15] eq 'incorrect original spelling' ){
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $iol = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$iol .= " $syn->[3] $trans->{'of'}->{$lang} " . i($syn->[16]) . " $syn->[17]";
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$iol .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$iol .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $iol) }
				elsif ($modal == 2) { $ios_list .= li({-class=>'exploli'}, $iol) }
			}
			elsif ( $syn->[15] eq 'incorrect subsequent spelling' ){
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $iel = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$iel .= " $syn->[3] $trans->{'of'}->{$lang} " . i($syn->[16]) . " $syn->[17]";
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$iel .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$iel .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $iel) }
				elsif ($modal == 2) { $ies_list .= li({-class=>'exploli'}, $iel) }
			}
			elsif ( $syn->[15] eq 'correct use' ){
				
				my @pub_use = publication($syn->[4], 0, 1, $dbc );
				
				unless (exists $chres{$syn->[0]}) { 
					$chres{$syn->[0]} = {};
					$chres{$syn->[0]}{'label'} = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, 
					i($syn->[1]) . " $syn->[2]" ) . " $trans->{'cited_in'}->{$lang} ";
					
					$chres{$syn->[0]}{'refs'} = ();
					my $page;
					if ($syn->[18]) { $page = ": $syn->[18]" }
					push(@{$chres{$syn->[0]}{'refs'}}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" ) . getPDF($syn->[4]));
				}
				else {
					my $page;
					if ($syn->[18]) { $page = ": $syn->[18]" }
					push(@{$chres{$syn->[0]}{'refs'}}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" ) . getPDF($syn->[4]));						
				}
			}
			elsif ( $syn->[15] eq 'homonym' ){
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $hl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$hl .= " $syn->[3] $trans->{'of'}->{$lang} " . i($syn->[16]) . " $syn->[17]";
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$hl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$hl .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $hl) }
				elsif ($modal == 2) { $hom_list .= li({-class=>'exploli'}, $hl) }
			}
			elsif ( $syn->[15] eq 'nomen nudum' ){
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $nl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$nl .=  " " . i($syn->[3]) . " $trans->{'of'}->{$lang} " . i($syn->[16]) . " $syn->[17]";
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$nl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$nl .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $nl) }
				elsif ($modal == 2) { $nn_list .= li({-class=>'exploli'}, $nl) }
			}
			elsif ( $syn->[15] eq 'status revivisco' or $syn->[15] eq 'combinatio revivisco' ){
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $nl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$nl .=  " " . i($syn->[3]);
			       	if ($syn->[1] ne $syn->[16] or $syn->[2] ne $syn->[17]) { $nl .= " $trans->{'toen'}->{$lang} " . i($syn->[16]) . " $syn->[17]"; }
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$nl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$nl .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $nl) }
				elsif ($modal == 2) { $nn_list .= li({-class=>'exploli'}, $nl) }
			}
			elsif ( $syn->[15] eq 'nomen praeoccupatum' ){
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $npl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$npl .= " " . i($syn->[3]) . " $trans->{'fromto'}->{$lang} " . i($syn->[16]) . " $syn->[17] " . i($trans->{'nnov'}->{$lang});
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$npl .= ", $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$npl .= getPDF($syn->[5]);
				}
				if ($syn->[14] eq $name->[4] and 0) { $nomstat .= '&nbsp; ' . i($trans->{'nnov'}->{$lang}) }
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $npl) }
				elsif ($modal == 2) { $np_list .= li({-class=>'exploli'}, $npl) }
			}
			elsif ( $syn->[15] eq 'nomen oblitum' ){
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $npl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$npl .= " " . i($syn->[3]) . ", $trans->{'synonym'}->{$lang} $trans->{'of'}->{$lang} " . i($syn->[16]) . " $syn->[17] " . i($trans->{'nprotect'}->{$lang});
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$npl .= ", $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$npl .= getPDF($syn->[5]);
				}
				if ($syn->[14] eq $name->[4]) { $nomstat .= '&nbsp; ' . i($trans->{'nprotect'}->{$lang}) }
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $npl) }
				elsif ($modal == 2) { $np_list .= li({-class=>'exploli'}, $npl) }
			}
			elsif ( $syn->[15] eq 'outside taxon' ){
				my $npl = i($syn->[1]) . " $syn->[2]";
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $npl) }
			}
			else {
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $ukl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$ukl .= " $syn->[3] $trans->{'of'}->{$lang} " . i($syn->[16]) . " $syn->[17]";
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$ukl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$ukl .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $ukl) }
				elsif ($modal == 2) { $uk_list .= li({-class=>'exploli'}, $ukl) }
			}
		}
		
		foreach (keys %chres) {
			my $cl = $chres{$_}{'label'};
			if ($chres{$_}{'refs'}) { $cl .= join (', ', @{$chres{$_}{'refs'}}); }
			$ch_list .= li({-class=>'exploli'}, $cl);
		}

		if ($display) { $display =  h4({-class=>'exploh4'}, ucfirst($trans->{'synonymie'}->{$lang})) . ul({-class=>'exploul'}, $display); }
		if ( $ch_list ) {
			$ch_tab = h4({-class=>'exploh4'}, $trans->{'Chresonym(s)'}->{$lang});
			$ch_tab .= ul({-class=>'exploul'}, $ch_list);
		}
		
		my $map;
		my @countries;
		if ($dbase eq 'flow' or $dbase eq 'flow2' or url_param('mode') eq 'full' or $mode eq 'full') {
			my %tgdone;
			my @tdwg4;
			my $areas;
			my %level1;
			if ( scalar @{$sp_ids} or $genus_id ){
				
				foreach my $species_id (@{$sp_ids}, $genus_id) { 
	
					my $sth5 = $dbc->prepare( "	SELECT 	ref_pays, 
										p.$lang, 
										p.en, 
										p.tdwg, 
										p.tdwg_level, 
										p.parent, 
										ref_publication_ori,
										page_ori,
										ref_publication_maj,
										page_maj
									FROM taxons_x_pays AS txp 
									LEFT JOIN pays AS p ON txp.ref_pays = p.index
									LEFT JOIN publications  AS pub ON pub.index = ref_publication_ori
									WHERE txp.ref_taxon = $species_id and p.en != 'Unknown'
									ORDER  BY p.$lang, pub.annee;" );
					
					$sth5->execute( );
					my ( $country_id, $country, $en, $tdwg, $level, $parent, $ref_pub_ori, $page_ori, $ref_pub_maj, $page_maj );
					$sth5->bind_columns( \( $country_id, $country, $en, $tdwg, $level, $parent, $ref_pub_ori, $page_ori, $ref_pub_maj, $page_maj ) );
					while ( $sth5->fetch ) {
						
						#if ($level eq '1') { $level1{$tdwg} = 1; }
						#elsif ($level eq '2') { 
						#	if ($parent) {
						#		$level1{$parent} = 1;
						#	}
						#}
						#elsif ($level eq '3') { 
						#	if ($parent) {
						#		my ($l1) = @{request_row("SELECT parent FROM pays WHERE tdwg = '$parent';", $dbc)};
						#		$level1{$l1} = 1;
						#	}
						#}
						#elsif ($level eq '4') { 
						#	if ($parent) {
						#		my ($l1) = @{request_row("SELECT parent FROM pays WHERE tdwg = (SELECT parent FROM pays WHERE tdwg = '$parent');", $dbc)};
						#		$level1{$l1} = 1;
						#	}
						#}
						unless (exists $tgdone{$tdwg.'/'.$en}) {
							
							my @fathers;
							
							if (length($tdwg) >= 5) { 
								
								if ($parent) {
									my ($father) = request_row("SELECT en FROM pays WHERE tdwg = '$parent';",$dbc,1);
									if ($father eq $en) { push(@fathers, $parent) }
									else { push(@tdwg4, $tdwg); }
								}
								else {
									push(@tdwg4, $tdwg);
								}
							} else {
								push(@fathers, $tdwg);
							}
							
							while (scalar(@fathers)) {
								my $sons = request_tab("SELECT tdwg FROM pays WHERE parent IN ('" . join("', '",@fathers) . "');",$dbc,1);
								
								@fathers = ();
								
								if (scalar(@{$sons})) {
									foreach (@{$sons}) {
										if (length($_) >= 5) { 
											push(@tdwg4, $_); 
										}
										else { push(@fathers, $_); }
									}
								}
							}
							$tgdone{$tdwg.'/'.$en} = 1;
							my @tmp = ($country_id, $country);
							push(@countries, \@tmp);
						}
					}
				}
			}
			
			my $bgsea;
			my $bgearth;
			my $bdearth;
			my $cclr;
			my $cdbr;
			my $wdth;
			
			if ($dbase eq 'psylles') { 
				$bgsea = '000000';
				$bgearth = '282828';
				$bdearth = '282828';
				$cclr = '99dd44';
				$cdbr = '99dd44';
				$wdth = 700 
			}
			elsif ($dbase eq 'cool') { 
				$bgsea = '8D1610';
				$bgearth = '650C06';
				$bdearth = '650C06';
				$cclr = 'FFCC66';
				$cdbr = 'EEBB55';
				$wdth = 500 
			}
			elsif ($dbase eq 'flow' or $dbase eq 'flow2') { 
				$bgsea = '';
				$bgearth = 'BBBBBB';
				$bdearth = 'DDDDDD';
				$cclr = '000066';
				$cdbr = 'DDDDDD';
				$wdth = 700 
			}
			else { 
				$bgsea = '';
				$bgearth = 'CCCCCC';
				$bdearth = 'CCCCCC';
				$cclr = '0F5286';
				$cdbr = '0F5286';
				$wdth = 500 
			}
			
			my $mapok;
			if (scalar(@tdwg4)) {
				$areas .= 'tdwg4:a:'.join(',', @tdwg4).'||';
				$mapok = 1;
			}
			#if (scalar(keys(%level1)) == 0) {} else { my ($key) = keys(%level1); if ($key == 6) { $mapok = 0; } $areas .= "tdwg1:b:$key"; }
			if ($bgearth eq $bdearth) {
				$areas .= "tdwg1:b:1,2,3,4,5,6,7,8,9";
			}
			else {
				$areas = substr($areas,0,-2);
				$areas = "tdwg4:b:".join(',',@{request_tab("SELECT tdwg FROM pays WHERE tdwg_level = '4' AND parent IN (SELECT tdwg FROM pays WHERE tdwg_level = '3');", $dbc, 1)})."||$areas";
			}
			$areas = "ad=$areas";
			
			my $styles = "as=a:$cclr,$cdbr,0|b:$bgearth,$bdearth,0";
			
			if ($mapok) {
				$map = "<script type='text/javascript'>
				function ImageMax(chemin) {
					var html = '<html> <head> <title>Distribution</title> </head> <body style=\"background: #$bgsea;\"><IMG style=\"background: #$bgsea;\" src='+chemin+' BORDER=0 NAME=ImageMax></body></html>';
					var popupImage = window.open('','_blank','toolbar=0, location=0, scrollbars=0, directories=0, status=0, resizable=1, width=1020, height=520');
					popupImage.document.open();
					popupImage.document.write(html);
					popupImage.document.close()
				};
				</script>
					<img id='cmap' style='background: #$bgsea;' src='$maprest?$areas&$styles&ms=$wdth' onMouseOver=\"this.style.cursor='pointer';\"  onclick=\"ImageMax($maprest?$areas&$styles&ms=1000');\">". br. br;
			}
		}
		
		my $countries_list;
		if ( scalar(@countries) ){
			
			$countries_list =   div({-class=>'mapdiv'},
						span({-id=>'ctrdisp',	-class=>'disparrow',
									-style=>'display: block; float: left;',
									-onMouseOver=>  "document.getElementById('ctrdisp').style.cursor = 'pointer';",
									-onClick=>"	document.getElementById('ctrdisp').style.display = 'none';
											document.getElementById('ctrhide').style.display = 'block';
											document.getElementById('paysdiv').style.display = 'block';"}, '') . 
						span({-id=>'ctrhide',	-class=>'hidearrow',
									-style=>'display: none; float: left;',
									-onMouseOver=>  "document.getElementById('ctrhide').style.cursor = 'pointer';",
									-onClick=>"	document.getElementById('ctrhide').style.display = 'none';
											document.getElementById('ctrdisp').style.display = 'block';
											document.getElementById('paysdiv').style.display = 'none';"}, '') . 
						h4({-class=>'exploh4',	-id=>'cttitle',
									-style=>'display: inline; margin-left: 6px;',
									-onMouseOver=>  "this.style.cursor = 'pointer';",
									-onClick=>"	if (document.getElementById('paysdiv').style.display == 'block') {
												document.getElementById('ctrhide').style.display = 'none';
												document.getElementById('ctrdisp').style.display = 'block';
												document.getElementById('paysdiv').style.display = 'none';
											}
											else{
												document.getElementById('ctrdisp').style.display = 'none';
												document.getElementById('ctrhide').style.display = 'block';
												document.getElementById('paysdiv').style.display = 'block';
											}"}, 
											$trans->{"geodistribution"}->{$lang}) . p .
						div({-id=>'paysdiv', -style=>'display: none;'}, 
							ul({-class=>'exploul'},  
								join('', map { li({-class=>'exploli'}, 
								a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=$_->[0]"."XX"."$name->[4]"}, $_->[1] )); } sort {$a->[1] cmp $b->[1]} @countries 
								)
							)
						)
					);
		}
		
		my $vdisplay = get_vernaculars($dbc, 'txv.ref_taxon', $genus_id);
						
		$fullhtml = 	div({-class=>'explocontent'},
					$up,
					div({-class=>'hierarchy'}, a({-class=>'navlink', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=family&id=$family_id"}, $family_fullname )),
					#' > ',
					#$ge_tab,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{'genus'}->{$lang}),
						a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=genus&id=$genus_id"},
							span({-class=>'subject', -style=>'display: inline;'}, $ge_tab )
						), $nomstat, br,
						$publication_tab,
						$display,
						$ch_tab,
						$sg_tab,
						$sp_tab,
						$countries_list,
						$map,
						$vdisplay
					)
				);
				
		print $fullhtml;
			
		$dbc->disconnect;
	}
	else {}
}

# Subgenus card
#################################################################
sub subgenus_card {
	if ( my $dbc = db_connection($config) ) {
		my $subgenus_id = $id;
		my $sge_name;
		my $sge_tab;
		my $display;

		my ($family_fullname) = @{ request_row("SELECT parent_taxon_fullname((SELECT ref_taxon_parent FROM taxons WHERE index = $subgenus_id), 'family')", $dbc)};
		my ($family_id) = @{ request_row("SELECT parent_taxon_id((SELECT ref_taxon_parent FROM taxons WHERE index = $subgenus_id), 'family')", $dbc)};

		my ($genus_fullname) = @{ request_row("SELECT parent_taxon_fullname((SELECT ref_taxon_parent FROM taxons WHERE index = $subgenus_id), 'genus')", $dbc)};
		my ($genus_id) = @{ request_row("SELECT parent_taxon_id((SELECT ref_taxon_parent FROM taxons WHERE index = $subgenus_id), 'genus')", $dbc)};

		my $name = request_row("SELECT 	t.index, 
						n.orthographe, 
						n.autorite, 
						n.ref_publication_princeps, 
						n.index,
						page_princeps
					FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
					LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
					LEFT JOIN noms AS ni ON ni.index = n.index
					LEFT JOIN rangs AS r ON t.ref_rang = r.index
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					WHERE s.en = 'valid' AND ref_taxon = $subgenus_id;",$dbc);

		$sge_tab = i("$name->[1]") . " $name->[2]";
		$sge_name = "$name->[1] $name->[2]";

		my ( $previous_id, $prev_name, $prev_autority, $next_id, $next_name, $next_autority, $stop, $current_id, $current_name, $current_authority );
		$dbc->{RaiseError} = 1;
		
		my $sth2 = $dbc->prepare( "SELECT t.index, nc.orthographe, nc.autorite
								FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
								LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
								LEFT JOIN noms AS n ON txn.ref_nom = n.index
								LEFT JOIN statuts AS s ON txn.ref_statut = s.index
								LEFT JOIN rangs AS r ON t.ref_rang = r.index
								WHERE r.en = 'subgenus' AND s.en = 'valid'
								ORDER BY LOWER ( n.orthographe ), nc.orthographe;" );
		$sth2->execute( );
		$sth2->bind_columns( \( $current_id, $current_name, $current_authority ) );
		while ( $sth2->fetch() ){
			if ( $stop ){
				( $next_id, $next_name, $next_autority ) = ( $current_id, $current_name, $current_authority );
				last;
			}
			else {
				if ( $current_id == $subgenus_id ){
					$stop = 1;
				}
				else {
					( $previous_id, $prev_name, $prev_autority ) = ( $current_id, $current_name, $current_authority );
				}
			}
		}
		$sth2->finish();

		my $up;
		if ($dbase ne 'cool' and $dbase ne 'flow' and $dbase ne 'flow2' and $dbase ne 'strepsiptera') {
			$up = 	div({-class=>'navup'}, 
					$totop, span({-class=>'navarrow'},' > '),
					makeup('genera', $trans->{'genus(s)'}->{$lang}, lc(substr($sge_name, 0, 1)))
				);
		}
			
		#$up .= prev_next_card( $card, $previous_id, i($prev_name) . " $prev_autority", $next_id, i($next_name) ." $next_autority" );

		my $publication_tab;
		if ( $name->[3] ) {
			#if ($name->[5]) { 
			#	$display .= li({-class=>'exploli'}, $sge_tab . " " . $trans->{'DescriptNewSsGr'}->{$lang} . " $trans->{'dansin'}->{$lang} " .  publication($name->[3], 0, 1, $dbc ) . ": $name->[5]");
			#}
			$publication_tab = h4({-class=>'exploh4'}, $trans->{'ori_pub'}->{$lang});
			my $pub = pub_formating($name->[3], $dbc, $name->[5] );
			$publication_tab .= div({-class=>'pubdiv'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$name->[3]"}, "$pub") . getPDF($name->[3]));
		}
		else {
			#$publication_tab = div({-class=>'pubdiv'}, $trans->{"UNK"}->{$lang});
		}

		my $ranks_ids = get_rank_ids( $dbc );
		my $sp_tab;
		my $sp_ids = son_taxa($subgenus_id, $ranks_ids->{"species"}->{"index"}, $dbc);
		if ( scalar @{$sp_ids} ){
			my $ids = "(";
			map { $ids .= "$_,"} @{$sp_ids};
			$ids =~ s/,$/)/;
			my $sp_list = request_tab("SELECT t.index, n.orthographe, n.autorite, n.gen_type FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
			LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
			LEFT JOIN rangs AS r ON t.ref_rang = r.index
			LEFT JOIN statuts AS s ON txn.ref_statut = s.index
			WHERE s.en = 'valid' AND t.index IN $ids
			ORDER BY LOWER ( n.orthographe );",$dbc);
			
			if ( scalar @{$sp_list} ){ 
			
				$sp_tab .= h4({-class=>'exploh4'}, scalar @{$sp_list} . " $trans->{'species(s)'}->{$lang}");
				$sp_tab .= start_ul({-class=>'exploul'});
				foreach my $sp ( @{$sp_list} ){
					my $typestr;
					if ($sp->[3]) { $typestr = span({-style=>'color: red'}, "&nbsp;  $trans->{'typespe'}->{$lang}") }
					$sp_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$sp->[0]"}, i("$sp->[1]") . " $sp->[2] $typestr" ) );
				}
				$sp_tab .= end_ul();
			}
		}
		else {
			#$sp_tab = ul({-class=>'exploul'}, li({-class=>'exploli'}, $trans->{"UNK"}->{$lang}));
		}
                
		my $synss = request_tab(	"SELECT nc.index, 
							nc.orthographe, 
							nc.autorite, 
							s.$lang, 
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
							s.en, 
							nc2.orthographe, 
							nc2.autorite,
							txn.page_utilisant,
							txn.page_denonciation
						FROM taxons_x_noms AS txn 
						LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
						LEFT JOIN noms_complets AS nc2 ON nc2.index = txn.ref_nom_cible
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index 
						LEFT JOIN noms AS n ON txn.ref_nom = n.index
						LEFT JOIN publications As pubd ON pubd.index = txn.ref_publication_denonciation
						LEFT JOIN publications As pubu ON pubu.index = txn.ref_publication_utilisant
						WHERE txn.ref_taxon = $subgenus_id 
						AND s.en not in ('correct use', 'valid', 'dead end') 
						ORDER BY n.annee, n.parentheses, pubu.annee, pubd.annee;",$dbc);


		my ( $syn_list, $typos_list, $combi_list, $wid_list, $os_list, $ios_list, $ies_list, $pid_list, $em_list, $ch_list, $hom_list, $nn_list, $np_list, $uk_list );
		my $modal= 1;
		my $nomstat;
		my %chres;
		my $ch_tab;
			
		foreach my $syn ( @{$synss} ){
						
			if ( $syn->[15] eq 'synonym' or $syn->[15] eq 'junior synonym' ){
				#my $ambiguous = synonymy( $syn->[6], $syn->[8], $syn->[10] );
				#my $complete = completeness( $syn->[7], $syn->[9], $syn->[11] );
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $sl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$sl .= " $syn->[3] $trans->{'of'}->{$lang} " . i($syn->[16]) . " $syn->[17]";
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$sl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$sl .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $sl) }
				elsif ($modal == 2) { $syn_list .= li({-class=>'exploli'}, $sl) }
			}
			elsif ( $syn->[15] eq 'wrong spelling' ){
				my @pub_use = publication($syn->[4], 0, 1, $dbc );
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $wsl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$wsl .= " $syn->[3] $trans->{'of'}->{$lang} " . i($syn->[16]) . " $syn->[17]";
				if ($pub_use[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$wsl .= " $trans->{'dansin'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" );
					$wsl .= getPDF($syn->[4]);
				}
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$wsl .= " $trans->{'corrby'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$wsl .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $wsl) }
				elsif ($modal == 2) { $typos_list .= li({-class=>'exploli'}, $wsl) }
			}
			elsif ( $syn->[15] eq 'previous combination' ){
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $tl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]");
				$tl .= " $syn->[3] $trans->{'of'}->{$lang} " . i($syn->[16]) . " $syn->[17]";
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$tl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$tl .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $tl) }
				elsif ($modal == 2) { $combi_list .= li({-class=>'exploli'}, $tl) }
			}
			elsif ( $syn->[15] eq 'misidentification' ){
				my @pub_use = publication($syn->[4], 0, 1, $dbc );
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $mil .= a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2] $syn->[3]" );
				if ($pub_use[1]) { 
					my $page;
					if ($syn->[18]) { $page = ": $syn->[18]" }
					$mil .= " $trans->{'dansin'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" );
					$mil .= getPDF($syn->[4]);
				}
				if ($pub_den[1]) {
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$mil .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$mil .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $mil) }
				elsif ($modal == 2) { $wid_list .= li({-class=>'exploli'}, $mil) }
			}
			elsif ( $syn->[15] eq 'previous identification' ){
			
				my @pub_use = publication($syn->[4], 0, 1, $dbc );
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $pil .= a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$pil .= " $trans->{'misid'}->{$lang} $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
				if ($pub_use[1]) { 
					my $page;
					if ($syn->[18]) { $page = ": $syn->[18]" }
					$pil .= " $trans->{'dansin'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" );
					$pil .= getPDF($syn->[4]);
				}
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$pil .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$pil .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $pil) }
				elsif ($modal == 2) { $pid_list .= li({-class=>'exploli'}, $pil) }
			}
			elsif ( $syn->[15] eq 'incorrect original spelling' ){
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $iol = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$iol .= " $syn->[3] $trans->{'of'}->{$lang} " . i($syn->[16]) . " $syn->[17]";
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$iol .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$iol .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $iol) }
				elsif ($modal == 2) { $ios_list .= li({-class=>'exploli'}, $iol) }
			}
			elsif ( $syn->[15] eq 'incorrect subsequent spelling' ){
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $iel = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$iel .= " $syn->[3] $trans->{'of'}->{$lang} " . i($syn->[16]) . " $syn->[17]";
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$iel .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$iel .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $iel) }
				elsif ($modal == 2) { $ies_list .= li({-class=>'exploli'}, $iel) }
			}
			elsif ( $syn->[15] eq 'correct use' ){
				
				my @pub_use = publication($syn->[4], 0, 1, $dbc );
				
				unless (exists $chres{$syn->[0]}) { 
					$chres{$syn->[0]} = {};
					$chres{$syn->[0]}{'label'} = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, 
					i($syn->[1]) . " $syn->[2]" ) . " $trans->{'cited_in'}->{$lang} ";
					
					my $page;
					if ($syn->[18]) { $page = ": $syn->[18]" }
					$chres{$syn->[0]}{'refs'} = ();
					push(@{$chres{$syn->[0]}{'refs'}}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" ) . getPDF($syn->[4]));
				}
				else {
					my $page;
					if ($syn->[18]) { $page = ": $syn->[18]" }
					push(@{$chres{$syn->[0]}{'refs'}}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" ) . getPDF($syn->[4]));						
				}
			}
			elsif ( $syn->[15] eq 'homonym' ){
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $hl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$hl .= " $syn->[3] $trans->{'of'}->{$lang} " . i($syn->[16]) . " $syn->[17]";
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$hl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$hl .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $hl) }
				elsif ($modal == 2) { $hom_list .= li({-class=>'exploli'}, $hl) }
			}
			elsif ( $syn->[15] eq 'nomen nudum' ){
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $nl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$nl .=  " " . i($syn->[3]) . " $trans->{'of'}->{$lang} " . i($syn->[16]) . " $syn->[17]";
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$nl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$nl .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $nl) }
				elsif ($modal == 2) { $nn_list .= li({-class=>'exploli'}, $nl) }
			}
			elsif ( $syn->[15] eq 'status revivisco' or $syn->[15] eq 'combinatio revivisco' ){
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $nl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$nl .=  " " . i($syn->[3]);
			       	if ($syn->[1] ne $syn->[16] or $syn->[2] ne $syn->[17]) { $nl .= " $trans->{'toen'}->{$lang} " . i($syn->[16]) . " $syn->[17]"; }
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$nl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$nl .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $nl) }
				elsif ($modal == 2) { $nn_list .= li({-class=>'exploli'}, $nl) }
			}
			elsif ( $syn->[15] eq 'nomen praeoccupatum' ){
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $npl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$npl .= " " . i($syn->[3]) . " $trans->{'fromto'}->{$lang} " . i($syn->[16]) . " $syn->[17] " . i($trans->{'nnov'}->{$lang});
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$npl .= ", $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$npl .= getPDF($syn->[5]);
				}
				if ($syn->[14] eq $name->[4] and 0) { $nomstat .= '&nbsp; ' . i($trans->{'nnov'}->{$lang}) }
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $npl) }
				elsif ($modal == 2) { $np_list .= li({-class=>'exploli'}, $npl) }
			}
			elsif ( $syn->[15] eq 'nomen oblitum' ){
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $npl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$npl .= " " . i($syn->[3]) . ", $trans->{'synonym'}->{$lang} $trans->{'of'}->{$lang} " . i($syn->[16]) . " $syn->[17] " . i($trans->{'nprotect'}->{$lang});
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$npl .= ", $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$npl .= getPDF($syn->[5]);
				}
				if ($syn->[14] eq $name->[4]) { $nomstat .= '&nbsp; ' . i($trans->{'nprotect'}->{$lang}) }
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $npl) }
				elsif ($modal == 2) { $np_list .= li({-class=>'exploli'}, $npl) }
			}
			elsif ( $syn->[15] eq 'outside taxon' ){
				my $npl = i($syn->[1]) . " $syn->[2]";
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $npl) }
			}
			else {
				my @pub_den = publication($syn->[5], 0, 1, $dbc );
				my $ukl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
				$ukl .= " $syn->[3] $trans->{'of'}->{$lang} " . i($syn->[16]) . " $syn->[17]";
				if ($pub_den[1]) { 
					my $page;
					if ($syn->[19]) { $page = ": $syn->[19]" }
					$ukl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
					$ukl .= getPDF($syn->[5]);
				}
				if ($modal == 1) { $display .= li({-class=>'exploli'}, $ukl) }
				elsif ($modal == 2) { $uk_list .= li({-class=>'exploli'}, $ukl) }
			}
		}
		
		foreach (keys %chres) {
			my $cl = $chres{$_}{'label'};
			if ($chres{$_}{'refs'}) { $cl .= join (', ', @{$chres{$_}{'refs'}}); }
			$ch_list .= li({-class=>'exploli'}, $cl);
		}

		if ($display) { $display =  h4({-class=>'exploh4'}, ucfirst($trans->{'synonymie'}->{$lang})) . ul({-class=>'exploul'}, $display); }
		if ( $ch_list ) {
			$ch_tab = h4({-class=>'exploh4'}, $trans->{'Chresonym(s)'}->{$lang});
			$ch_tab .= ul({-class=>'exploul'}, $ch_list);
		}
		
		my $map;
		my @countries;
		if ($dbase eq 'flow' or $dbase eq 'flow2' or url_param('mode') eq 'full' or $mode eq 'full') {
			my %tgdone;
			my @tdwg4;
			my $areas;
			my %level1;
			if ( scalar @{$sp_ids} or $subgenus_id ){
				
				foreach my $species_id (@{$sp_ids}, $subgenus_id) { 
	
					my $sth5 = $dbc->prepare( "SELECT ref_pays, p.$lang, p.en, p.tdwg, p.tdwg_level, p.parent, ref_publication_ori
									FROM taxons_x_pays AS txp 
									LEFT JOIN pays AS p ON txp.ref_pays = p.index
									LEFT JOIN publications  AS pub ON pub.index = ref_publication_ori
									WHERE txp.ref_taxon = $species_id and p.en != 'Unknown'
									ORDER  BY p.$lang, pub.annee;" );
					
					$sth5->execute( );
					my ( $country_id, $country, $en, $tdwg, $level, $parent, $ref_pub_ori );
					$sth5->bind_columns( \( $country_id, $country, $en, $tdwg, $level, $parent, $ref_pub_ori ) );
					while ( $sth5->fetch ) {
								
						#if ($level eq '1') { $level1{$tdwg} = 1; }
						#elsif ($level eq '2') { 
						#	if ($parent) {
						#		$level1{$parent} = 1;
						#	}
						#}
						#elsif ($level eq '3') { 
						#	if ($parent) {
						#		my ($l1) = @{request_row("SELECT parent FROM pays WHERE tdwg = '$parent';", $dbc)};
						#		$level1{$l1} = 1;
						#	}
						#}
						#elsif ($level eq '4') { 
						#	if ($parent) {
						#		my ($l1) = @{request_row("SELECT parent FROM pays WHERE tdwg = (SELECT parent FROM pays WHERE tdwg = '$parent');", $dbc)};
						#		$level1{$l1} = 1;
						#	}
						#}
						unless (exists $tgdone{$tdwg.'/'.$en}) {
							
							my @fathers;
							
							if (length($tdwg) >= 5) { 
								
								if ($parent) {
									my ($father) = request_row("SELECT en FROM pays WHERE tdwg = '$parent';",$dbc,1);
									if ($father eq $en) { push(@fathers, $parent) }
									else { push(@tdwg4, $tdwg); }
								}
								else {
									push(@tdwg4, $tdwg);
								}
							} else {
								push(@fathers, $tdwg);
							}
							
							while (scalar(@fathers)) {
								my $sons = request_tab("SELECT tdwg FROM pays WHERE parent IN ('" . join("', '",@fathers) . "');",$dbc,1);
								
								@fathers = ();
								
								if (scalar(@{$sons})) {
									foreach (@{$sons}) {
										if (length($_) >= 5) { 
											push(@tdwg4, $_); 
										}
										else { push(@fathers, $_); }
									}
								}
							}
							$tgdone{$tdwg.'/'.$en} = 1;
							my @tmp = ($country_id, $country);
							push(@countries, \@tmp);
						}
					}
				}
			}
			
			my $bgsea;
			my $bgearth;
			my $bdearth;
			my $cclr;
			my $cdbr;
			my $wdth;
			
			if ($dbase eq 'psylles') { 
				$bgsea = '000000';
				$bgearth = '282828';
				$bdearth = '282828';
				$cclr = '99dd44';
				$cdbr = '99dd44';
				$wdth = 700 
			}
			elsif ($dbase eq 'cool') { 
				$bgsea = '8D1610';
				$bgearth = '650C06';
				$bdearth = '650C06';
				$cclr = 'FFCC66';
				$cdbr = 'EEBB55';
				$wdth = 500 
			}
			elsif ($dbase eq 'flow' or $dbase eq 'flow2') { 
				$bgsea = '';
				$bgearth = 'BBBBBB';
				$bdearth = 'DDDDDD';
				$cclr = '000066';
				$cdbr = 'DDDDDD';
				$wdth = 700 
			}
			else { 
				$bgsea = '';
				$bgearth = 'CCCCCC';
				$bdearth = 'CCCCCC';
				$cclr = '0F5286';
				$cdbr = '0F5286';
				$wdth = 500 
			}
			
			my $mapok;
			if (scalar(@tdwg4)) {
				$areas .= 'tdwg4:a:'.join(',', @tdwg4).'||';
				$mapok = 1;
			}
			#if (scalar(keys(%level1)) == 0) {} else { my ($key) = keys(%level1); if ($key == 6) { $mapok = 0; } $areas .= "tdwg1:b:$key"; }
			if ($bgearth eq $bdearth) {
				$areas .= "tdwg1:b:1,2,3,4,5,6,7,8,9";
			}
			else {
				$areas = substr($areas,0,-2);
				$areas = "tdwg4:b:".join(',',@{request_tab("SELECT tdwg FROM pays WHERE tdwg_level = '4' AND parent IN (SELECT tdwg FROM pays WHERE tdwg_level = '3');", $dbc, 1)})."||$areas";
			}
			$areas = "ad=$areas";
			
			my $styles = "as=a:$cclr,$cdbr,0|b:$bgearth,$bdearth,0";
			
			if ($mapok) {
				$map = "<script type='text/javascript'>
				function ImageMax(chemin) {
					var html = '<html> <head> <title>Distribution</title> </head> <body style=\"background: #$bgsea;\"><IMG style=\"background: #$bgsea;\" src='+chemin+' BORDER=0 NAME=ImageMax></body></html>';
					var popupImage = window.open('','_blank','toolbar=0, location=0, scrollbars=0, directories=0, status=0, resizable=1, width=1020, height=520');
					popupImage.document.open();
					popupImage.document.write(html);
					popupImage.document.close()
				};
				</script>
					<img id='cmap' style='background: #$bgsea;' src='$maprest?$areas&$styles&ms=$wdth' onMouseOver=\"this.style.cursor='pointer';\"  onclick=\"ImageMax($maprest?$areas&$styles&ms=1000');\">". br. br;
			}
		}
		
		my $countries_list;
		if ( scalar(@countries) ){
			
			$countries_list =   div({-class=>'mapdiv'},
						span({-id=>'ctrdisp',	-class=>'disparrow',
									-style=>'display: block; float: left;',
									-onMouseOver=>  "document.getElementById('ctrdisp').style.cursor = 'pointer';",
									-onClick=>"	document.getElementById('ctrdisp').style.display = 'none';
											document.getElementById('ctrhide').style.display = 'block';
											document.getElementById('paysdiv').style.display = 'block';"}, '') . 
						span({-id=>'ctrhide',	-class=>'hidearrow',
									-style=>'display: none; float: left;',
									-onMouseOver=>  "document.getElementById('ctrhide').style.cursor = 'pointer';",
									-onClick=>"	document.getElementById('ctrhide').style.display = 'none';
											document.getElementById('ctrdisp').style.display = 'block';
											document.getElementById('paysdiv').style.display = 'none';"}, '') . 
						h4({-class=>'exploh4',	-id=>'cttitle',
									-style=>'display: inline; margin-left: 6px;',
									-onMouseOver=>  "this.style.cursor = 'pointer';",
									-onClick=>"	if (document.getElementById('paysdiv').style.display == 'block') {
												document.getElementById('ctrhide').style.display = 'none';
												document.getElementById('ctrdisp').style.display = 'block';
												document.getElementById('paysdiv').style.display = 'none';
											}
											else{
												document.getElementById('ctrdisp').style.display = 'none';
												document.getElementById('ctrhide').style.display = 'block';
												document.getElementById('paysdiv').style.display = 'block';
											}"}, 
											$trans->{"geodistribution"}->{$lang}) . p .
						div({-id=>'paysdiv', -style=>'display: none;'}, 
							ul({-class=>'exploul'},  
								join('', map { li({-class=>'exploli'}, 
								a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=$_->[0]"."XX"."$name->[4]"}, $_->[1] )); } sort {$a->[1] cmp $b->[1]} @countries 
								)
							)
						)
					);
		}
		
		my $vdisplay = get_vernaculars($dbc, 'txv.ref_taxon', $subgenus_id);
						
		$fullhtml = 	div({-class=>'explocontent'},
					$up,
					div({-class=>'hierarchy'},
						a({-class=>'navlink', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=family&id=$family_id"}, $family_fullname ),
						span({-class=>'navarrow'},' > '),
						a({-class=>'navlink', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=genus&id=$genus_id"}, $genus_fullname ),

					),
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, ucfirst($trans->{'subgenus'}->{$lang})),
						a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=subgenus&id=$subgenus_id"},
							span({-class=>'subject', -style=>'display: inline;'}, $sge_tab )
						), $nomstat, br,
						$publication_tab,
						$display,
						$ch_tab,
						$sp_tab,
						$countries_list,
						$map,
						$vdisplay
					)
				);
				
		print $fullhtml;
			
		$dbc->disconnect;
	}
	else {}
}

# Species card
#################################################################
sub species_card {
		
	# display modes:
	# s = specimens
	
	if ( my $dbc = db_connection($config) ) {
		my $species_id = $id;
		my $sp_name;
		my $sp_tab;
		my %spcnames;
		my $graphic;
		
		 my ($family_fullname) = @{ request_row("SELECT parent_taxon_fullname((SELECT ref_taxon_parent FROM taxons WHERE index = $species_id), 'family')", $dbc)};
		 my ($family_id) = @{ request_row("SELECT parent_taxon_id ((SELECT ref_taxon_parent FROM taxons WHERE index = $species_id), 'family')", $dbc)};
		 
		 my ($genus_fullname) = @{ request_row("SELECT parent_taxon_fullname((SELECT ref_taxon_parent FROM taxons WHERE index = $species_id), 'genus')", $dbc)};
		 my ($genus_id) = @{ request_row("SELECT parent_taxon_id ((SELECT ref_taxon_parent FROM taxons WHERE index = $species_id), 'genus')", $dbc)};

		# fetch species complete name
		my $name = request_row("SELECT 	nc.orthographe, 
						nc.autorite, 
						nc.ref_publication_princeps, 
						nc.index, 
						n.orthographe, 
						n.ref_nom_parent,
						n.page_princeps,
						t.distribution_complete,
						t.plantes_completes
					FROM taxons_x_noms AS txn 
					LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
					LEFT JOIN noms AS n ON nc.index = n.index
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN taxons AS t ON t.index = $species_id
					WHERE txn.ref_taxon = $species_id AND s.en = 'valid';",$dbc);
		$sp_tab = i("$name->[0]") . " $name->[1]";
		$sp_name = "$name->[0] $name->[1]";
		
		$spcnames{$name->[3]}{'species'} = $name->[4];
		
		if ($mode =~ m/s/) {
			my $val = $name->[5];
			my $found = 0;
			while (!$found) {
				my ($father) = @{request_row("SELECT ref_nom_parent from noms where index = $val", $dbc)};
				
				unless ($father) { $found = 1; }
				else { $val = $father; }
			}
			($spcnames{$name->[3]}{'genus'}) = @{request_row("SELECT orthographe from noms where index = $val", $dbc)};
		}
		
		my $ranks_ids = get_rank_ids( $dbc );
		my $ssp_tab;
		my $ssp_ids = son_taxa($species_id, $ranks_ids->{"subspecies"}->{"index"}, $dbc);
		if ( scalar @{$ssp_ids} ){
			my $ids = "(";
			map { $ids .= "$_,"} @{$ssp_ids};
			$ids =~ s/,$/)/;
			my $ssp_list = request_tab("SELECT t.index, n.orthographe, n.autorite FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
			LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
			LEFT JOIN rangs AS r ON t.ref_rang = r.index
			LEFT JOIN statuts AS s ON txn.ref_statut = s.index
			WHERE s.en = 'valid' AND t.index IN $ids
			ORDER BY LOWER ( n.orthographe );",$dbc);

			if ( scalar(@{$ssp_list})) {
				if ( scalar(@{$ssp_list}) == 1 ){ 
					$ssp_tab .= h4({-class=>'exploh4'}, scalar @{$ssp_list} . " $trans->{'subspecies'}->{$lang}"); 
				}
				else { 
					$ssp_tab .= h4({-class=>'exploh4'}, scalar @{$ssp_list} . " $trans->{'subspecies(s)'}->{$lang}"); 
				}
				$ssp_tab .= start_ul({-class=>'exploul'});
				foreach my $ssp ( @{$ssp_list} ){
					$ssp_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=subspecies&id=$ssp->[0]"}, i("$ssp->[1]") . " $ssp->[2]" ) );
				}
				$ssp_tab .= end_ul();
			}
		}
		else {
			#$sp_tab = ul({-class=>'exploul'}, li({-class=>'exploli'}, $trans->{"UNK"}->{$lang}));
		}
		
		#Get previous and next id
		my ( $previous_id, $prev_name, $prev_autority, $next_id, $next_name, $next_autority, $stop, $current_id, $current_name, $current_authority );
		$dbc->{RaiseError} = 1;
		my $sth2 = $dbc->prepare( "SELECT t.index, nc.orthographe, nc.autorite
								FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
								LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
								LEFT JOIN noms AS n ON txn.ref_nom = n.index
								LEFT JOIN statuts AS s ON txn.ref_statut = s.index
								LEFT JOIN rangs AS r ON t.ref_rang = r.index
								WHERE r.en = 'species' AND s.en = 'valid'
								ORDER BY nc.orthographe;" );
		$sth2->execute( );
		$sth2->bind_columns( \( $current_id, $current_name, $current_authority ) );
		my ($first_id, $first_name, $first_authority);
		
		while ( $sth2->fetch() ){
			if ( $stop ){
				( $next_id, $next_name, $next_autority ) = ( $current_id, $current_name, $current_authority );
				$stop = 2;
				last;
			}
			else {
				if ( $current_id == $species_id ){
					$stop = 1;
				}
				else {
					( $previous_id, $prev_name, $prev_autority ) = ( $current_id, $current_name, $current_authority );
				}
			}
		}
		unless ($stop == 2) { ( $next_id, $next_name, $next_autority ) = ( $first_id, $first_name, $first_authority ); }
		$sth2->finish(); # finalize the request

		my $up;
		if ($dbase ne 'cool' and $dbase ne 'flow' and $dbase ne 'flow2' and $dbase ne 'strepsiptera') {
			$up = 	div({-class=>'navup'}, 
					$totop, span({-class=>'navarrow'},' > '),
					makeup('speciess', $trans->{'speciess'}->{$lang}, lc(substr($sp_name, 0, 1)))
				);
		}
				
		if ($dbase eq 'flow' or $dbase eq 'flow2' or $dbase eq 'strepsiptera') {
			$up .=  div({-class=>'navup'}, 
					prev_next_card( $card, $previous_id, i($prev_name) . " $prev_autority", $next_id, i($next_name) ." $next_autority" )
				);
		}
		
		if ($dbase eq 'cipa') {
			$up .=  prev_next_card( $card, $previous_id, i($prev_name) . " $prev_autority", $next_id, i($next_name) ." $next_autority" );
		}
				
		# fetch species synonyms
		my @names_index;
		push(@names_index, $name->[3]);
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
							txn.page_utilisant,
							txn.page_denonciation
						FROM taxons_x_noms AS txn 
						LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						LEFT JOIN noms_complets AS nc2 ON nc2.index = txn.ref_nom_cible
						LEFT JOIN noms AS n ON nc.index = n.index
						LEFT JOIN publications As pubd ON pubd.index = txn.ref_publication_denonciation
						LEFT JOIN publications As pubu ON pubu.index = txn.ref_publication_utilisant
						LEFT JOIN publications As pubo ON pubo.index = nc.ref_publication_princeps
						WHERE txn.ref_taxon = $species_id AND s.en not in ('valid', 'dead end') ORDER BY pubd.annee, n.annee, n.parentheses, pubu.annee;",$dbc);
		
		my $nomstat;
		my $modal = 1;
		my $display;
		# fetch princeps publication
		my $publication_tab;
		if (  $name->[2] ) {
			#if ($name->[6]) { 
			#	$display .= li({-class=>'exploli'}, $sp_tab . " " . $trans->{'DescriptNewSp'}->{$lang} . " $trans->{'dansin'}->{$lang} " .  publication($name->[2], 0, 1, $dbc ) . ": $name->[6]");
			#}
			$publication_tab = h4({-class=>'exploh4'}, $trans->{"ori_pub"}->{$lang});
			my $pub = pub_formating($name->[2], $dbc, $name->[6] );
			$publication_tab .= div({-class=>'pubdiv'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$name->[2]"}, "$pub") . getPDF($name->[2]));
		}
		else {
			#$publication_tab = div({-class=>'pubdiv'}, $trans->{"UNK"}->{$lang});
		}
		
		my ( $syn_list, $typos_list, $combi_list, $wid_list, $os_list, $ios_list, $ies_list, $pid_list, $em_list, $ch_list, $hom_list, $nn_list, $np_list, $uk_list );
		my ( $syn_tab, $typos_tab, $combi_tab, $wid_tab, $os_tab, $ch_tab, $hom_tab, $nn_tab, $np_tab, $uk_tab, $ios_tab, $ies_tab, $pid_tab );
		my %chres;
		if ( scalar @{$names_list} != 0 or $display ) {
			
			if ($mode =~ m/s/) {
					
				foreach my $syn ( @{$names_list} ){
					
					unless (exists($spcnames{$syn->[0]})) {
					
						$spcnames{$syn->[0]}{'species'} = $syn->[18];
					
						my $val = $syn->[19];
						my $found = 0;
						while (!$found) {
							my ($father) = @{request_row("SELECT ref_nom_parent from noms where index = $val", $dbc)};
							
							unless ($father) { $found = 1; }
							else { $val = $father; }
						}
						($spcnames{$syn->[0]}{'genus'}) = @{request_row("SELECT orthographe from noms where index = $val", $dbc)};
					}
				}
			}
			my (@statuses, @uses);
			my $protect = 0;
			foreach my $syn ( @{$names_list} ){
								
				push(@names_index, $syn->[0]);
				if ( $syn->[3] eq 'synonym' or $syn->[3] eq 'junior synonym' ){
					#my $ambiguous = synonymy( $syn->[6], $syn->[8], $syn->[10] );
					#my $complete = completeness( $syn->[7], $syn->[9], $syn->[11] );
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $sl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$sl .= " $syn->[17] $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
					if ($pub_den[1]) { 
						my $page;
						if ($syn->[21]) { $page = ": $syn->[21]" }
						$sl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
						$sl .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $sl) }
					elsif ($modal == 2) { $syn_list .= li({-class=>'exploli'}, $sl) }
					push(@statuses, "[\"$syn->[1]\",\"$syn->[2]\",\"$syn->[3]\",\"$syn->[15]\",\"$syn->[16]\",\"$pub_den[1]\"]");
				}
				elsif ( $syn->[3] eq 'wrong spelling' ){
					my @pub_use = publication($syn->[4], 0, 1, $dbc );
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $wsl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$wsl .= " $syn->[17] $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
					if ($pub_use[1]) { 
						my $page;
						if ($syn->[20]) { $page = ": $syn->[20]" }
						$wsl .= " $trans->{'dansin'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" );
						$wsl .= getPDF($syn->[4]);
					}
					if ($pub_den[1]) { 
						my $page;
						if ($syn->[21]) { $page = ": $syn->[21]" }
						$wsl .= " $trans->{'corrby'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
						$wsl .= getPDF($syn->[5]);
					}
					if ($modal == 1) { 
						#$display .= li({-class=>'exploli'}, $wsl);
						$chres{$syn->[0].$syn->[4].$syn->[20]}{'label'} = $wsl;
					}
					elsif ($modal == 2) { $typos_list .= li({-class=>'exploli'}, $wsl) }
					push(@uses, "[\"$syn->[1]\",\"$syn->[2]\",\"$syn->[3]\",\"$syn->[15]\",\"$syn->[16]\",\"$pub_den[1]\"]");
				}
				elsif ( $syn->[3] eq 'previous combination' ){
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $tl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]");
					$tl .= " $syn->[17] $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
					if ($pub_den[1]) { 
						my $page;
						if ($syn->[21]) { $page = ": $syn->[21]" }
						$tl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
						$tl .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $tl) }
					elsif ($modal == 2) { $combi_list .= li({-class=>'exploli'}, $tl) }
					push(@statuses, "[\"$syn->[1]\",\"$syn->[2]\",\"$syn->[3]\",\"$syn->[15]\",\"$syn->[16]\",\"$pub_den[1]\"]");
				}
				elsif ( $syn->[3] eq 'misidentification' ){
					my @pub_use = publication($syn->[4], 0, 1, $dbc );
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $mil .= a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2] $syn->[17]" );
					if ($pub_use[1]) { 
						my $page;
						if ($syn->[20]) { $page = ": $syn->[20]" }
						$mil .= " $trans->{'dansin'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" );
						$mil .= getPDF($syn->[4]);
					}
					if ($pub_den[1]) {
						my $page;
						if ($syn->[21]) { $page = ": $syn->[21]" }
					       	$mil .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
						$mil .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $mil) }
					elsif ($modal == 2) { $wid_list .= li({-class=>'exploli'}, $mil) }
					push(@uses, "[\"$syn->[1]\",\"$syn->[2]\",\"$syn->[3]\",\"\",\"\",\"$pub_den[1]\"]");
				}
				elsif ( $syn->[3] eq 'previous identification' ){
				
					my @pub_use = publication($syn->[4], 0, 1, $dbc );
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $pil .= a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$pil .= " $trans->{'misid'}->{$lang} $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
					if ($pub_use[1]) { 
						my $page;
						if ($syn->[20]) { $page = ": $syn->[20]" }
						$pil .= " $trans->{'dansin'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" );
						$pil .= getPDF($syn->[4]);
					}
					if ($pub_den[1]) { 
						my $page;
						if ($syn->[21]) { $page = ": $syn->[21]" }
						$pil .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
						$pil .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $pil) }
					elsif ($modal == 2) { $pid_list .= li({-class=>'exploli'}, $pil) }
					push(@uses, "[\"$syn->[1]\",\"$syn->[2]\",\"$syn->[3]\",\"$syn->[15]\",\"$syn->[16]\",\"$pub_den[1]\"]");
				}
				elsif ( $syn->[3] eq 'incorrect original spelling' ){
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $iol = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$iol .= " $syn->[17] $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
					if ($pub_den[1]) { 
						my $page;
						if ($syn->[21]) { $page = ": $syn->[21]" }
						$iol .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
						$iol .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $iol) }
					elsif ($modal == 2) { $ios_list .= li({-class=>'exploli'}, $iol) }
					push(@statuses, "[\"$syn->[1]\",\"$syn->[2]\",\"$syn->[3]\",\"$syn->[15]\",\"$syn->[16]\",\"$pub_den[1]\"]");
				}
				elsif ( $syn->[3] eq 'incorrect subsequent spelling' ){
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $iel = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$iel .= " $syn->[17] $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
					if ($pub_den[1]) { 
						my $page;
						if ($syn->[21]) { $page = ": $syn->[21]" }
						$iel .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
						$iel .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $iel) }
					elsif ($modal == 2) { $ies_list .= li({-class=>'exploli'}, $iel) }
					push(@statuses, "[\"$syn->[1]\",\"$syn->[2]\",\"$syn->[3]\",\"$syn->[15]\",\"$syn->[16]\",\"$pub_den[1]\"]");
				}
				elsif ( $syn->[3] eq 'correct use' ){
					
					my @pub_use = publication($syn->[4], 0, 1, $dbc );
					
					unless (exists $chres{$syn->[0]}) { 
						$chres{$syn->[0]} = {};
						$chres{$syn->[0]}{'label'} = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, 
						i($syn->[1]) . " $syn->[2]" ) . " $trans->{'cited_in'}->{$lang} ";
						
						my $page;
						if ($syn->[20]) { $page = ": $syn->[20]" }
						$chres{$syn->[0]}{'refs'} = ();
						push(@{$chres{$syn->[0]}{'refs'}}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" ) . getPDF($syn->[4]));
					}
					else {
						my $page;
						if ($syn->[20]) { $page = ": $syn->[20]" }
						push(@{$chres{$syn->[0]}{'refs'}}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" ) . getPDF($syn->[4]));						
					}
					push(@uses, "[\"$syn->[1]\",\"$syn->[2]\",\"$syn->[3]\",\"\",\"\",\"$pub_use[1]\"]");
				}
				elsif ( $syn->[3] eq 'homonym' ){
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $hl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$hl .= " $syn->[17] $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
					if ($pub_den[1]) { 
						my $page;
						if ($syn->[21]) { $page = ": $syn->[21]" }
						$hl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
						$hl .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $hl) }
					elsif ($modal == 2) { $hom_list .= li({-class=>'exploli'}, $hl) }
					push(@statuses, "[\"$syn->[1]\",\"$syn->[2]\",\"$syn->[3]\",\"$syn->[15]\",\"$syn->[16]\",\"$pub_den[1]\"]");
				}
				elsif ( $syn->[3] eq 'nomen nudum' ){
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $nl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$nl .=  " " . i($syn->[17]) . " $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
					if ($pub_den[1]) { 
						my $page;
						if ($syn->[21]) { $page = ": $syn->[21]" }
						$nl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
						$nl .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $nl) }
					elsif ($modal == 2) { $nn_list .= li({-class=>'exploli'}, $nl) }
					push(@statuses, "[\"$syn->[1]\",\"$syn->[2]\",\"$syn->[3]\",\"$syn->[15]\",\"$syn->[16]\",\"$pub_den[1]\"]");
				}
				elsif ( $syn->[3] eq 'status revivisco' or $syn->[3] eq 'combinatio revivisco' ){
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $nl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$nl .=  " " . i($syn->[17]);
					if ($syn->[1] ne $syn->[15] or $syn->[2] ne $syn->[16]) { $nl .= " $trans->{'toen'}->{$lang} " . i($syn->[15]) . " $syn->[16]"; }
					if ($pub_den[1]) { 
						my $page;
						if ($syn->[21]) { $page = ": $syn->[21]" }
						$nl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
						$nl .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $nl) }
					elsif ($modal == 2) { $nn_list .= li({-class=>'exploli'}, $nl) }
					push(@statuses, "[\"$syn->[1]\",\"$syn->[2]\",\"$syn->[3]\",\"$syn->[15]\",\"$syn->[16]\",\"$pub_den[1]\"]");
				}
				elsif ( $syn->[3] eq 'nomen praeoccupatum' ){
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $npl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$npl .= " " . i($syn->[17]) . " $trans->{'fromto'}->{$lang} " . i($syn->[15]) . " $syn->[16] " . i($trans->{'nnov'}->{$lang});
					if ($pub_den[1]) { 
						my $page;
						if ($syn->[21]) { $page = ": $syn->[21]" }
						$npl .= ", $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
						$npl .= getPDF($syn->[5]);
					}
					if ($syn->[14] eq $name->[3] and 0) { $nomstat .= '&nbsp; ' . i($trans->{'nnov'}->{$lang}) }
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $npl) }
					elsif ($modal == 2) { $np_list .= li({-class=>'exploli'}, $npl) }
					push(@statuses, "[\"$syn->[1]\",\"$syn->[2]\",\"$syn->[3]\",\"$syn->[15]\",\"$syn->[16]\",\"$pub_den[1]\"]");
				}
				elsif ( $syn->[3] eq 'nomen oblitum' ){
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $npl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$npl .= " " . i($syn->[17]) . ", $trans->{'synonym'}->{$lang} $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16] " . i($trans->{'nprotect'}->{$lang});
					if ($pub_den[1]) { 
						my $page;
						if ($syn->[21]) { $page = ": $syn->[21]" }
						$npl .= ", $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
						$npl .= getPDF($syn->[5]);
					}
					if ($syn->[14] eq $name->[3] and !$protect) { $nomstat .= '&nbsp; ' . i($trans->{'nprotect'}->{$lang}); $protect = 1; }
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $npl) }
					elsif ($modal == 2) { $np_list .= li({-class=>'exploli'}, $npl) }
					push(@statuses, "[\"$syn->[1]\",\"$syn->[2]\",\"$syn->[3]\",\"$syn->[15]\",\"$syn->[16]\",\"$pub_den[1]\"]");
				}
				#elsif ( $syn->[15] eq 'outside taxon' ){
				#	my $npl = i($syn->[1]) . " $syn->[2]";
				#	if ($modal == 1) { $display .= li({-class=>'exploli'}, $npl) }
				#}
				else {
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $ukl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$ukl .= " $syn->[17] $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
					if ($pub_den[1]) { 
						my $page;
						if ($syn->[21]) { $page = ": $syn->[21]" }
						$ukl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
						$ukl .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $ukl) }
					elsif ($modal == 2) { $uk_list .= li({-class=>'exploli'}, $ukl) }
					push(@statuses, "[\"$syn->[1]\",\"$syn->[2]\",\"$syn->[3]\",\"$syn->[15]\",\"$syn->[16]\",\"$pub_den[1]\"]");
				}
			}
			if (scalar(@statuses) or scalar(@uses)) {
				my $arrays = "var synonyms = [".join(',',@statuses)."]; var uses = [".join(',',@uses)."]; var valid = [\"$name->[0]\",\"$name->[1]\"]; ";
				$graphic = 	div({-style=>'display: inline;'},
							start_form(-name=>'historyForm', -method=>'post', -action=>"http://hemiptera.infosyslab.fr/cgi-bin/nameHistory.pl?name=$name->[0] $name->[1]", -target=>'_blank', -style=>'display: inline;'),
							hidden('arrays', $arrays),
							span({-onMouseover=>"this.style.cursor='pointer';", -onClick=>"historyForm.submit();", -style=>"margin-left: 20px; color: red; font-weight: normal;"}, 
							#$trans->{'graphdisp'}->{$lang}
							#'&nbsp;&nbsp;'
							),
							end_form()
						);
				#my @stats = @{ request_tab("SELECT en FROM statuts ORDER by en", $dbc, 1)};
				#$jscript .= 'var statuses = ["'.join('","',@stats).'"];';
				#$jscript = "	<SCRIPT language=\"Javascript\">
				#		 <!--
				#		 	$jscript
				#		// -->
				#		</SCRIPT>";
				#$jscript .= "	<SCRIPT LANGUAGE=\"Javascript\" SRC=\"fichier.js\"> </SCRIPT>";
			}
			
			foreach (keys %chres) {
				my $cl = $chres{$_}{'label'};
				if ($chres{$_}{'refs'}) { $cl .= join (', ', @{$chres{$_}{'refs'}}); }
				$ch_list .= li({-class=>'exploli'}, $cl);
			}
			
			if ($modal == 2) {
				if ( $syn_list ){
					$syn_tab = h4({-class=>'exploh4'}, $trans->{'synonyms'}->{$lang});
					$syn_tab .= ul({-class=>'exploul'}, $syn_list); 
				}
				if ( $typos_list ){
					$typos_tab = h4({-class=>'exploh4'}, $trans->{'typos'}->{$lang});
					$typos_tab .= ul({-class=>'exploul'}, $typos_list); 
				}
				if ( $combi_list ){
					$combi_tab = h4({-class=>'exploh4'}, $trans->{'ori_coms'}->{$lang});
					$combi_tab .= ul({-class=>'exploul'}, $combi_list); 
				}
				if ( $wid_list ){
					$wid_tab = h4({-class=>'exploh4'}, $trans->{'id_error'}->{$lang});
					$wid_tab .= ul({-class=>'exploul'}, $wid_list); 
				}
				if ( $os_list ){
					$os_tab = h4({-class=>'exploh4'}, $trans->{'other_sex'}->{$lang});
					$os_tab .= ul({-class=>'exploul'}, $os_list); 
				}
				if ( $ch_list ) {
					$ch_tab = h4({-class=>'exploh4'}, $trans->{'Chresonym(s)'}->{$lang});
					$ch_tab .= ul({-class=>'exploul'}, $ch_list);
				}
				if ( $hom_list ) {
					$hom_tab = h4({-class=>'exploh4'}, $trans->{'Homonym(s)'}->{$lang});
					$hom_tab .= ul({-class=>'exploul'}, $hom_list);
				}
				if ( $nn_list ) {
					$nn_tab = h4({-class=>'exploh4'}, i(ucfirst($trans->{'Nomen_nudum'}->{$lang})));
					$nn_tab .= ul({-class=>'exploul'}, $nn_list);
				}
				if ( $np_list ) {
					$np_tab = h4({-class=>'exploh4'}, i(ucfirst($trans->{'Nomen_praeoccupatum'}->{$lang})));
					$np_tab .= ul({-class=>'exploul'}, $np_list);
				}
				if ( $uk_list ) {
					$uk_tab = h4({-class=>'exploh4'}, $trans->{'nom_act(s)'}->{$lang});
					$uk_tab .= ul({-class=>'exploul'}, $uk_list);
				}
				if ( $ios_list ) {
					$ios_tab = h4({-class=>'exploh4'}, $trans->{'ios(s)'}->{$lang});
					$ios_tab .= ul({-class=>'exploul'}, $ios_list);
				}
				if ( $ies_list ) {
					$ies_tab = h4({-class=>'exploh4'}, $trans->{'ies(s)'}->{$lang});
					$ies_tab .= ul({-class=>'exploul'}, $ies_list);
				}
				if ( $pid_list ) {
					$pid_tab = h4({-class=>'exploh4'}, $trans->{'pid(s)'}->{$lang});
					$pid_tab .= ul({-class=>'exploul'}, $pid_list);
				}
				
				$display = $combi_tab.$syn_tab.$hom_tab.$np_tab.$ios_tab.$ies_tab.$nn_tab.$ch_tab.$typos_tab.$wid_tab.$pid_tab.$uk_tab.$os_tab;
			}
			else { 
				if ($display) { $display =  h4({-class=>'exploh4'}, ucfirst($trans->{'synonymie'}->{$lang}) . $graphic) . ul({-class=>'exploul'}, $display); }
				if ( $ch_list ) {
					$ch_tab = h4({-class=>'exploh4'}, $trans->{'Chresonym(s)'}->{$lang});
					$ch_tab .= ul({-class=>'exploul'}, $ch_list);
				}
				$display .= $ch_tab;
			}
		}
		
		my @disp_modes = ();
		if ($dbase eq 'coleorrhyncha' or $dbase eq 'strepsiptera') { @disp_modes = ('none', 'block', 'block'); }
		else { @disp_modes = ('block', 'none', 'none'); }

		my $plants = [];
		if ($dbase ne 'cipa') {
			$plants = request_tab("	SELECT 	p1.index, 
							p1.nom, 
							p2.nom, 
							p3.nom, 
							txp.ref_publication_ori, 
							txp.certitude, 
							p1.autorite, 
							r.en, 
							p1.statut, 
							p1.ref_valide, 
							txp.page_ori, 
							txp.ref_publication_maj, 
							txp.page_maj,
							(get_host_plant(p1.ref_valide)).nom,
							(get_host_plant(p1.ref_valide)).autorite,
							(get_host_plant(p1.ref_valide)).famille
						FROM plantes AS p1 
						LEFT JOIN plantes AS p2 ON (p1.ref_parent = p2.index)
						LEFT JOIN plantes AS p3 ON (p2.ref_parent = p3.index)
						LEFT JOIN taxons_x_plantes AS txp ON (p1.index = txp.ref_plante)
						LEFT JOIN rangs AS r ON p1.ref_rang = r.index
						LEFT JOIN publications AS pub ON pub.index = txp.ref_publication_ori
						WHERE txp.ref_taxon = $species_id
						AND r.en in ('family','genus', 'species')
						ORDER BY p2.nom, p1.nom, p3.nom, pub.annee;",$dbc,2);
		}

		my $current;
		my $string;
		my @pubs;
		my $confirm;
		my $tabpl;
		my $partial;
		my $nbp = 0;
		if (($dbase eq 'psylles' or $dbase eq 'cool') and !$name->[8]) { $partial = "&nbsp; ($trans->{partial}->{$lang})"; } else { $partial = '' }
		if ( scalar @{$plants} ){
			foreach my $row ( @{$plants} ){
				my $pdisp;
			        if ("$row->[0]/$row->[5]" ne $current) {
					if ($current) {
						if (scalar(@pubs)) { $string .= "&nbsp; $trans->{'segun'}->{$lang} &nbsp;" . join(', ', @pubs);  }
						$tabpl .= li({-class=>'exploli'}, "$string $confirm");
					}
					
					$nbp++;
					$current = "$row->[0]/$row->[5]";
					@pubs = ();
					$confirm = '';
					my $pid = $row->[9] || $row->[0];
					my $val;
					$val = $row->[13] ? i($row->[13]) : undef;
					$val .= $row->[14] ? ' '.$row->[14] : '';
					$val .= $row->[15] ? ' ('.$row->[15].')' : '';
					$val = $val ? ' [ '.$val.' ]' : undef;
					if ($row->[3]) { 
						$string = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plant&id=$pid"}, i("$row->[2] $row->[1]") . " $row->[6] ($row->[3])".$val); 
					}
					elsif ($row->[2]) { $string = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plant&id=$pid"}, i($row->[1]) . " $row->[6] ($row->[2])".$val) }
					else { $string = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plant&id=$pid"}, $row->[1].$val) }
				}

				if ($row->[4]) {
					my $page;
					if ($row->[10]) { $page = ": $row->[10]" }
					my @p = publication($row->[4], 0, 1, $dbc);
					push(@pubs, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$row->[4]"}, "$p[1]$page") . getPDF($row->[4]));
				}
				
				if ($row->[5] eq 'uncertain') { $confirm = "&nbsp; [ $trans->{'doubtful'}->{$lang} ]"; }
				elsif ($row->[5] eq 'certain') { $confirm = "&nbsp; [&nbsp;$trans->{'confirmed'}->{$lang}&nbsp;]"; }
			}

			if ($string) {
				if (scalar(@pubs)) { $string .= "&nbsp; $trans->{'segun'}->{$lang} &nbsp;" . join(', ', @pubs);  }
				if ($plants->[$#{$plants}][5] eq 'uncertain') { $confirm = "&nbsp; [ $trans->{'doubtful'}->{$lang} ]"; }
				elsif ($plants->[$#{$plants}][5] eq 'certain') { $confirm = "&nbsp; [&nbsp;$trans->{'confirmed'}->{$lang}&nbsp;]"; }
				$tabpl .= li({-class=>'exploli'}, "$string $confirm");
			}
			
			if ($nbp < 4) { @disp_modes = ('none', 'block', 'block'); } else { @disp_modes = ('block', 'none', 'none'); }
			
			my $espace;
			if (!$display and $dbase eq 'psylles') { $espace = br; }
			
			$tabpl = 	$espace.
					div({-id=>'pltdisp',	-class=>'disparrow',
								-style=>"display: $disp_modes[0]; float: left;",
								-onMouseOver=>  "document.getElementById('pltdisp').style.cursor = 'pointer';",
								-onClick=>"	document.getElementById('pltdisp').style.display = 'none';
										document.getElementById('plthide').style.display = 'block';
										document.getElementById('plantsdiv').style.display = 'block';"}, '&nbsp;') . 
					div({-id=>'plthide',	-class=>'hidearrow',
								-style=>"display: $disp_modes[1]; float: left;",
								-onMouseOver=>  "document.getElementById('plthide').style.cursor = 'pointer';",
								-onClick=>"	document.getElementById('plthide').style.display = 'none';
										document.getElementById('pltdisp').style.display = 'block';
										document.getElementById('plantsdiv').style.display = 'none';"}, '&nbsp;') . 
					h4({-class=>'exploh4',	-style=>'display: inline; margin-left: 6px;',
								-onMouseOver=>  "this.style.cursor = 'pointer';",
								-onClick=>"	if (	document.getElementById('plantsdiv').style.display == 'block') {
											document.getElementById('plthide').style.display = 'none';
											document.getElementById('pltdisp').style.display = 'block';
											document.getElementById('plantsdiv').style.display = 'none';
										}
										else{
											document.getElementById('pltdisp').style.display = 'none';
											document.getElementById('plthide').style.display = 'block';
											document.getElementById('plantsdiv').style.display = 'block';
										}"}, 
										$trans->{"hostplant(s)"}->{$lang}) . $partial . p .
					div({-id=>'plantsdiv', -style=>"display: $disp_modes[2];"}, ul({-class=>'exploul'}, $tabpl));
		}
		
		my $tabassoc;
		if ($dbase eq 'strepsiptera') {
			my $assocs = request_tab("	SELECT 	ta.index,
								(get_taxon_associe(ta.index)).*,
								txt.ref_publication_ori, 
								txt.page_ori, 
								txt.ref_publication_maj, 
								txt.page_maj,
								ty.$lang,
								sx.$lang
							FROM taxons_associes AS ta 
							LEFT JOIN taxons_x_taxons_associes AS txt ON (ta.index = txt.ref_taxon_associe)
							LEFT JOIN types_association AS ty ON (ty.index = txt.ref_type_association)
							LEFT JOIN sexes AS sx ON (sx.index = txt.ref_sexe)
							LEFT JOIN publications AS pub ON pub.index = txt.ref_publication_ori
							WHERE txt.ref_taxon = $species_id
							AND ty.en = 'host'
							ORDER BY get_taxon_associe_full_name(ta.index);",$dbc,2);
							
	
	
			my $curr_ta;
			my $str_ta;
			my @pubs_ta;
			my $nba = 0;
			if ( scalar @{$assocs} ){
				foreach my $row ( @{$assocs} ){
					my $tadisp;
					if ($row->[0] ne $curr_ta) {
						if ($curr_ta) {
							if (scalar(@pubs_ta)) { $str_ta .= "&nbsp; $trans->{'segun'}->{$lang} &nbsp;" . join(', ', @pubs_ta);  }
							$tabassoc .= li({-class=>'exploli'}, "$str_ta");
						}
						$nba++;
						$curr_ta = $row->[0];
						@pubs_ta = ();
						
						if ($row->[10]) { $row->[10] = " ($row->[10])"; }
						my $str = i($row->[1]);
						if($row->[2]) { $str .= " $row->[2]" }
						my $higher;
						if($row->[3]) { $higher .= "&nbsp; $row->[3]" }
						if($row->[4]) { $higher .= " ($row->[4])" }
						if($row->[11]) { $row->[11] = span({-class=>'subject'}, " [$row->[11]]") }
						
						$str_ta = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=host&id=$row->[0]"}, $str) . $higher . $row->[11] ; 
					}
	
					if ($row->[6]) {
						my $page;
						if ($row->[7]) { $page = ": $row->[7]" }
						my @p = publication($row->[6], 0, 1, $dbc);
						push(@pubs_ta, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$row->[6]"}, "$p[1]$page") . getPDF($row->[6]));
					}
				}
	
				if ($str_ta) {
					if (scalar(@pubs_ta)) { $str_ta .= "&nbsp; $trans->{'segun'}->{$lang} &nbsp;" . join(', ', @pubs_ta);  }
					$tabassoc .= li({-class=>'exploli'}, $str_ta);
				}
				
				if ($nba < 4) { @disp_modes = ('none', 'block', 'block'); } else { @disp_modes = ('block', 'none', 'none'); }
				
				$tabassoc = 	div({-id=>'tadisp',	-class=>'disparrow',
									-style=>"display: $disp_modes[0]; float: left;",
									-onMouseOver=>  "document.getElementById('tadisp').style.cursor = 'pointer';",
									-onClick=>"	document.getElementById('tadisp').style.display = 'none';
											document.getElementById('tahide').style.display = 'block';
											document.getElementById('tadiv').style.display = 'block';"}, '&nbsp;') . 
						div({-id=>'tahide',	-class=>'hidearrow',
									-style=>"display: $disp_modes[1]; float: left;",
									-onMouseOver=>  "document.getElementById('tahide').style.cursor = 'pointer';",
									-onClick=>"	document.getElementById('tahide').style.display = 'none';
											document.getElementById('tadisp').style.display = 'block';
											document.getElementById('tadiv').style.display = 'none';"}, '&nbsp;') . 
						h4({-class=>'exploh4',	-style=>'display: inline; margin-left: 6px;',
									-onMouseOver=>  "this.style.cursor = 'pointer';",
									-onClick=>"	if (	document.getElementById('tadiv').style.display == 'block') {
												document.getElementById('tahide').style.display = 'none';
												document.getElementById('tadisp').style.display = 'block';
												document.getElementById('tadiv').style.display = 'none';
											}
											else{
												document.getElementById('tadisp').style.display = 'none';
												document.getElementById('tahide').style.display = 'block';
												document.getElementById('tadiv').style.display = 'block';
											}"}, 
											ucfirst($trans->{"host(s)"}->{$lang})) .
						div({-id=>'tadiv', -style=>"display: $disp_modes[2];"}, ul({-class=>'exploul'}, $tabassoc));
			}
		}
		
		my $regions = [];
	       
		if (0) {
			$regions = request_tab("SELECT r.index, r.nom
			FROM regions_biogeo AS r LEFT JOIN taxons_x_regions_biogeo AS txr ON (r.index = txr.ref_region_biogeo)
			WHERE txr.ref_taxon = $species_id;",$dbc);
		}
		
		my $vdisplay = get_vernaculars($dbc, 'txv.ref_taxon', $species_id);

		my $tabr;
		if ( scalar @{$regions} ){
			foreach my $row ( @{$regions} ){
				$tabr .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=region&id=$row->[0]"}, "$row->[1]") );
			}
			$tabr = h4({-class=>'exploh4'}, $trans->{"region_as"}->{$lang}) . ul({-class=>'exploul'}, $tabr);
		}
		
		# fetch images
		my $imagesurl;
		my $images = request_tab("SELECT icone_url, index, url FROM taxons_x_images AS txi LEFT JOIN images AS I ON txi.ref_image = I.index WHERE txi.ref_taxon = $species_id;",$dbc);
		
		my $images_types = [];
		$images_types = request_tab("	SELECT icone_url, I.index, url, nc.orthographe, nc.autorite
							FROM noms_x_images AS nxi 
							LEFT JOIN images AS I ON nxi.ref_image = I.index 
							LEFT JOIN noms_complets AS nc ON nxi.ref_nom = nc.index
							WHERE nxi.ref_nom in (".join(',', @names_index).");",$dbc);
		
		my $default_img_display = 'none';
		if ($dbase eq 'cool' or $dbase eq 'coleorrhyncha') { $default_img_display = 'block'; }
		
		if ( scalar @{$images} != 0 or scalar @{$images_types} != 0 ){
			$imagesurl = 	span({-id=>'imgdisp',	-class=>'disparrow',
								-style=>"display: $disp_modes[0]; float: left;",
								-onMouseOver=>  "document.getElementById('imgdisp').style.cursor = 'pointer';",
								-onClick=>"	document.getElementById('imgdisp').style.display = 'none';
										document.getElementById('imghide').style.display = 'block';
										document.getElementById('imgsdiv').style.display = 'block';"}, '&nbsp;') . 
					span({-id=>'imghide',	-class=>'hidearrow',
								-style=>"display: $disp_modes[1]; float: left;",
								-onMouseOver=>  "document.getElementById('imghide').style.cursor = 'pointer';",
								-onClick=>"	document.getElementById('imghide').style.display = 'none';
										document.getElementById('imgdisp').style.display = 'block';
										document.getElementById('imgsdiv').style.display = 'none';"}, '&nbsp;') .
					h4({-class=>'exploh4', 	-style=>'display: inline; margin-left: 6px;',
								-onMouseOver=>  "this.style.cursor = 'pointer';",
								-onClick=>"	if (	document.getElementById('imgsdiv').style.display == 'block') {
											document.getElementById('imghide').style.display = 'none';
											document.getElementById('imgdisp').style.display = 'block';
											document.getElementById('imgsdiv').style.display = 'none';
										}
										else{
											document.getElementById('imgdisp').style.display = 'none';
											document.getElementById('imghide').style.display = 'block';
											document.getElementById('imgsdiv').style.display = 'block';
										}"}, 
										ucfirst($trans->{'img(s)'}->{$lang}))  . p;
					

			$imagesurl .= "<DIV ID=imgsdiv STYLE='display: $default_img_display; float: none;'>";
			if ($dbase eq 'cool') {
				foreach my $row ( @{$images} ){
					$imagesurl .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"window.open('$row->[2]', '', 'toolbar=0, location=0, scrollbars=1, directories=0, status=0, resizable=1, width=1100, height=800');"}, img({-src=>"$row->[0]", -style=>'border: 0; margin: 0;'})));
				}
				foreach my $row ( @{$images_types}){
					$imagesurl .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"window.open('$row->[2]', '', 'toolbar=0, location=0, scrollbars=1, directories=0, status=0, resizable=1, width=1100, height=800');"}, img({-src=>"$row->[0]", -style=>'border: 0; margin: 0;'})));
				}				
			}
			else {
				foreach my $row ( @{$images} ){
					$imagesurl .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=image&id=$row->[1]&search=taxon"}, img({-src=>"$row->[0]", -style=>'border: 0; margin: 0;'})));
				}
				foreach my $row ( @{$images_types}){
					$imagesurl .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=image&id=$row->[1]&search=nom"}, img({-src=>"$row->[0]", -style=>'border: 0; margin: 0;'})));
				}
			}
			$imagesurl .= '</DIV>' . div({-style=>'clear: both; float: none;'});
		}

		# Fetch presence of the species in a country
		my $countries_list = '';
		$dbc->{RaiseError} = 1;
		
		my $sth5 = $dbc->prepare( "SELECT ref_pays, p.$lang, p.en, p.tdwg, p.tdwg_level, p.parent, ref_publication_ori, page_ori, precision
						FROM taxons_x_pays AS txp 
						LEFT JOIN pays AS p ON txp.ref_pays = p.index
						LEFT JOIN publications  AS pub ON pub.index = ref_publication_ori
						WHERE txp.ref_taxon = $species_id and p.en != 'Unknown'
						ORDER  BY p.$lang, pub.annee;" );

		$sth5->execute( );
		my ( $country_id, $country, $en, $tdwg, $level, $parent, $ref_pub_ori, $page_ori, $precision );
		$sth5->bind_columns( \( $country_id, $country, $en, $tdwg, $level, $parent, $ref_pub_ori, $page_ori, $precision ) );
		
		my $current;
		my $precis;
		my $string;
		my @pubs;
		my $sup = 'NULL';
		my (@tdwg2, @tdwg3, @tdwg4);
		my %tgdone;
		my %level1;
		my $nbpy = 0;
		while ( $sth5->fetch ) {
				my $pdisp;
			        if ($country_id != $current or $precision ne $precis) {
					if ($current) {
						if (scalar(@pubs)) { $string .= "&nbsp; $trans->{'segun'}->{$lang} &nbsp;" . join(', ', @pubs);  }
						$countries_list .= li({-class=>'exploli'}, "$string");
					}
					$nbpy++;
					$current = $country_id;
					$precis = $precision;
					@pubs = ();
					my $sep;
					if ($country =~ m/$sup \(/) { $sep = '&nbsp;&nbsp;&nbsp;' } else { $sup = $country }
					$string = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=$current"}, $sep . $country);
					if ($precision) { $string .= '&nbsp;' . $precision }
				}
					
				if ($ref_pub_ori) {
					my $page;
					if ($page_ori) { $page = ": $page_ori" }
					my @p = publication($ref_pub_ori, 0, 1, $dbc);
					push(@pubs, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$ref_pub_ori"}, "$p[1]$page") . getPDF($ref_pub_ori));
				}
				
				#if ($level eq '1') { $level1{$tdwg} = 1; }
				#elsif ($level eq '2') { 
				#	if ($parent) {
				#		$level1{$parent} = 1;
				#	}
				#}
				#elsif ($level eq '3') { 
				#	if ($parent) {
				#		my ($l1) = @{request_row("SELECT parent FROM pays WHERE tdwg = '$parent';", $dbc)};
				#		$level1{$l1} = 1;
				#	}
				#}
				#elsif ($level eq '4') { 
				#	if ($parent) {
				#		my ($l1) = @{request_row("SELECT parent FROM pays WHERE tdwg = (SELECT parent FROM pays WHERE tdwg = '$parent');", $dbc)};
				#		$level1{$l1} = 1;
				#	}
				#}
			
#				unless (exists $tgdone{$tdwg}) {
#					
#					if ($level eq '2') {
#						push(@tdwg2, $tdwg);
#					}
#					elsif ($level eq '3') {
#						push(@tdwg3, $tdwg);
#					}
#					elsif ($level eq '4') {
#						push(@tdwg4, $tdwg);
#					}
#					else { unless ($en eq 'Unknown') { die "Country $country has no valid tdwg level !!" } }
#					
#					$tgdone{$tdwg} = 1;
#				}
				
				unless (exists $tgdone{$tdwg.'/'.$en}) {
					
					my @fathers;
					
					if (length($tdwg) >= 5) { 
						
						if ($parent) {
							my ($father) = request_row("SELECT en FROM pays WHERE tdwg = '$parent';",$dbc,1);
							if ($father eq $en) { push(@fathers, $parent) }
							else { push(@tdwg4, $tdwg); }
						}
						else {
							push(@tdwg4, $tdwg);
						}
					} else {
						push(@fathers, $tdwg);
					}
					
					while (scalar(@fathers)) {
						my $sons = request_tab("SELECT tdwg FROM pays WHERE parent IN ('" . join("', '",@fathers) . "');",$dbc,1);
						
						@fathers = ();
						
						if (scalar(@{$sons})) {
							foreach (@{$sons}) {
								if (length($_) >= 5) { 
									push(@tdwg4, $_); 
								}
								else { push(@fathers, $_); }
							}
						}
					}
					$tgdone{$tdwg.'/'.$en} = 1;
				}

		}
		if (scalar(@pubs)) { $string .= "&nbsp; $trans->{'segun'}->{$lang} &nbsp;" . join(', ', @pubs); }
		if ($string) { $countries_list .= li({-class=>'exploli'}, "$string"); }
		
		if ($nbpy < 4) { @disp_modes = ('none', 'block', 'block'); } else { @disp_modes = ('block', 'none', 'none'); }
			
		#while ( $sth5->fetch ) {
		#	my $altitude = '';
		#	( $altitude_min or $altitude_max ) ? ( $altitude = " ($altitude_min m, $altitude_max m)" ) : ( $altitude = '' );
		#	( $altitude_min_min or $altitude_max_max ) ? ( $altitude .= " (min: $altitude_min_min m, max: $altitude_max_max m)" ) : ( $altitude .= '' );
		#	( $epoque_abondance ) ? ( $altitude .= " $epoque_abondance" ) : ( $altitude .= '' );
		#}
				
		$sth5->finish();
		my $map;
		my $areas;		
		if (($dbase eq 'psylles' or $dbase eq 'cool') and !$name->[7]) { $partial = "&nbsp; ($trans->{partial}->{$lang})"; } else { $partial = '' }
		if ( $countries_list ){
			$countries_list =   div({-class=>'mapdiv'},
						span({-id=>'ctrdisp',	-class=>'disparrow',
									-style=>"display: $disp_modes[0]; float: left;",
									-onMouseOver=>  "document.getElementById('ctrdisp').style.cursor = 'pointer';",
									-onClick=>"	document.getElementById('ctrdisp').style.display = 'none';
											document.getElementById('ctrhide').style.display = 'block';
											document.getElementById('paysdiv').style.display = 'block';"}, '') . 
						span({-id=>'ctrhide',	-class=>'hidearrow',
									-style=>"display: $disp_modes[1]; float: left;",
									-onMouseOver=>  "document.getElementById('ctrhide').style.cursor = 'pointer';",
									-onClick=>"	document.getElementById('ctrhide').style.display = 'none';
											document.getElementById('ctrdisp').style.display = 'block';
											document.getElementById('paysdiv').style.display = 'none';"}, '') . 
						h4({-class=>'exploh4',	-id=>'cttitle',
									-style=>"display: inline; margin-left: 6px;",
									-onMouseOver=>  "this.style.cursor = 'pointer';",
									-onClick=>"	if (document.getElementById('paysdiv').style.display == 'block') {
												document.getElementById('ctrhide').style.display = 'none';
												document.getElementById('ctrdisp').style.display = 'block';
												document.getElementById('paysdiv').style.display = 'none';
											}
											else{
												document.getElementById('ctrdisp').style.display = 'none';
												document.getElementById('ctrhide').style.display = 'block';
												document.getElementById('paysdiv').style.display = 'block';
											}"}, 
											$trans->{"geodistribution"}->{$lang}) . $partial . p.
						div({-id=>'paysdiv', -style=>"display: $disp_modes[2];"}, ul({-class=>'exploul'}, $countries_list)));
						
						my $bgsea;
						my $bgearth;
						my $bdearth;
						my $cclr;
						my $cdbr;
						my $wdth;
						
						if ($dbase eq 'psylles') { 
							$bgsea = '000000';
							$bgearth = '282828';
							$bdearth = '282828';
							$cclr = '99dd44';
							$cdbr = '99dd44';
							$wdth = 700 
						}
						elsif ($dbase eq 'cool') { 
							$bgsea = '8D1610';
							$bgearth = '650C06';
							$bdearth = '650C06';
							$cclr = 'FFCC66';
							$cdbr = 'EEBB55';
							$wdth = 500 
						}
						elsif ($dbase eq 'flow' or $dbase eq 'flow2') { 
							$bgsea = '';
							$bgearth = 'BBBBBB';
							$bdearth = 'DDDDDD';
							$cclr = '000066';
							$cdbr = 'DDDDDD';
							$wdth = 700 
						}
						elsif ($dbase eq 'strepsiptera') { 
							$bgsea = '';
							$bgearth = '5adb69';
							$bdearth = '5adb69';
							$cclr = '004400';
							$cdbr = '004400';
							$wdth = 500 
						}
						else { 
							$bgsea = '';
							$bgearth = 'CCCCCC';
							$bdearth = 'CCCCCC';
							$cclr = '0F5286';
							$cdbr = '0F5286';
							$wdth = 500 
						}
						
						my $mapok;
						if (scalar(@tdwg4)) {
							$areas .= 'tdwg4:a:'.join(',', @tdwg4).'||';
							$mapok = 1;
						}
						if (scalar(@tdwg3)) {
							$areas .= 'tdwg3:a:'.join(',', @tdwg3).'||';
							$mapok = 1;
						}
						if (scalar(@tdwg2)) {
							$areas .= 'tdwg2:a:'.join(',', @tdwg2).'||';
							$mapok = 1;
						}
						#if (scalar(keys(%level1)) == 0) {} else { my ($key) = keys(%level1); if ($key == 6) { $mapok = 0; } $areas .= "tdwg1:b:$key"; }
						#if ($bgearth eq $bdearth) {
						#	$areas .= "tdwg1:b:1,2,3,4,5,6,7,8,9";
						#}
						#else {
							$areas = substr($areas,0,-2);
							$areas = "tdwg4:b:".join(',',@{request_tab("SELECT tdwg FROM pays WHERE tdwg_level = '4' AND parent IN (SELECT tdwg FROM pays WHERE tdwg_level = '3');", $dbc, 1)})."||$areas";
						#}
						$areas = "ad=$areas";
						
						my $styles = "as=a:$cclr,$cdbr,0|b:$bgearth,$bdearth,0";
						
						#my $agent = LWP::UserAgent->new;
						#$agent->agent("MapRest");
						#my $connect = HTTP::Request->new(GET => $link);
						#my $res = $agent->request($connect);
						#if ($mapok and $res->is_success) {
						if ($mapok) {
							$map = "
							<script type='text/javascript'>
							function ImageMax(chemin) {
								var html = '<html> <head> <title>Distribution</title> </head> <body style=\"background: #$bgsea;\"><IMG style=\"background: #$bgsea;\" src='+chemin+' BORDER=0 NAME=ImageMax></body></html>';
								var popupImage = window.open('','_blank','toolbar=0, location=0, scrollbars=0, directories=0, status=0, resizable=1, width=1020, height=520');
								popupImage.document.open();
								popupImage.document.write(html);
								popupImage.document.close()
							};
							</script>
								<img id='cmap' style='background: #$bgsea;' src='$maprest?$areas&$styles&ms=$wdth&recalculate=false' onMouseOver=\"this.style.cursor='pointer';\"  onclick=\"ImageMax($maprest?$areas&$styles&ms=1000');\">". br. br;
						}
		}
		
		
		my $ua = LWP::UserAgent->new;
		$ua->agent("MNHNspec");
		
		my $speclinks;
		my $separator;
		if ($dbase eq 'flow' or $dbase eq 'flow2') { $separator = hr({-class=>'spec_separator'}); }
		
		if ($mode =~ m/s/) {
						
			my %done;
			
			foreach (keys(%spcnames)) {
				
				my $link = "http://coldb.mnhn.fr/ScientificName/" . $spcnames{$_}{'genus'} . '/' . $spcnames{$_}{'species'};
								
				my $req = HTTP::Request->new(GET => $link);
			
				my $res = $ua->request($req);
			
				if ($res->is_success) {
					unless ($done{$spcnames{$_}{'genus'} . ' ' . $spcnames{$_}{'species'}}) {					
						$speclinks .= 	br. $separator.
								a({-class=>'exploa', -href=>$link, -target=>'_blank'}, $trans->{'mnhn_spec_of'}->{$lang} . ' ' . $spcnames{$_}{'genus'} . ' ' . $spcnames{$_}{'species'} ) . br;
						
						$done{$spcnames{$_}{'genus'} . ' ' . $spcnames{$_}{'species'}} = 1;
					}
				}
			}
			
			unless ($speclinks) { $speclinks = $trans->{'no_mnhn_spec'}->{$lang}; }
						
			$speclinks = h4({-class=>'exploh4'}, $trans->{'mnhn_spec'}->{$lang}) . $speclinks . p;
		}
		
		unless ($dbase eq 'cipa' or $dbase eq 'strepsiptera' or $speclinks) { 
			my @params;
			foreach (keys(%labels)) { if ($labels{$_}) { push(@params, $_) } }
			my $args = join('&', map { "$_=$labels{$_}"} @params );
			
			$mode .= 's';

			$speclinks = $separator.
					h4({-class=>'exploh4'}, $trans->{'mnhn_spec'}->{$lang}) . a({-class=>'exploa', -href=>"$scripts{$dbase}$args&mode=$mode"}, $trans->{'check_mnhn_spec'}->{$lang}) . p;
		}
		
		if ($dbase eq 'cool' or $dbase eq 'psylles') { $countries_list = br . $countries_list; }
		
		if ($dbase eq 'cipa') { 
			$speclinks = display_cross_tables($species_id, $dbc);
		}
		
		unless($display) { $display = br; }
		
		$fullhtml = 	#$jscript.
				div({-class=>'explocontent'},
					$up,
					div({-class=>'hierarchy'},
						a({-class=>'navlink', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=family&id=$family_id"}, $family_fullname ),
						span({-class=>'navarrow'},' > '),
						a({-class=>'navlink', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=genus&id=$genus_id"}, $genus_fullname ),
						#' > ',
						#$sp_tab, p,
					),
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{'species'}->{$lang} ), 
						a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$species_id"},
							span({-class=>'subject', -style=>'display: inline;'}, $sp_tab )
						), $nomstat, br,
						$publication_tab,
						$ssp_tab,
						$display,
						$tabpl,
						$tabr,
						$countries_list,
						$map,
						$tabassoc,
						$imagesurl,
						$vdisplay,
						$speclinks
					)
				);
				
		print $fullhtml;
			
		$dbc->disconnect;
	}
	else {}
}

# Subspecies card
#################################################################
sub subspecies_card {
		
	# display modes:
	# s = specimens
	
	if ( my $dbc = db_connection($config) ) {
		my $subspecies_id = $id;
		my $ssp_name;
		my $ssp_tab;
		my %sspcnames;
				 
		 my ($genus_fullname) = @{ request_row("SELECT parent_taxon_fullname((SELECT ref_taxon_parent FROM taxons WHERE index = $subspecies_id), 'genus')", $dbc)};
		 my ($genus_id) = @{ request_row("SELECT parent_taxon_id ((SELECT ref_taxon_parent FROM taxons WHERE index = $subspecies_id), 'genus')", $dbc)};
		 
		 my ($species_fullname) = @{ request_row("SELECT parent_taxon_fullname((SELECT ref_taxon_parent FROM taxons WHERE index = $subspecies_id), 'species')", $dbc)};
		 my ($species_id) = @{ request_row("SELECT parent_taxon_id ((SELECT ref_taxon_parent FROM taxons WHERE index = $subspecies_id), 'species')", $dbc)};

		# fetch species complete name
		my $name = request_row("SELECT nc.orthographe, nc.autorite, nc.ref_publication_princeps, nc.index, n.orthographe, n.ref_nom_parent
								FROM taxons_x_noms AS txn 
								LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
								LEFT JOIN noms AS n ON nc.index = n.index
								LEFT JOIN statuts AS s ON txn.ref_statut = s.index
								WHERE txn.ref_taxon = $subspecies_id AND s.en = 'valid';",$dbc);
		$ssp_tab = i("$name->[0]") . " $name->[1]";
		$ssp_name = "$name->[0] $name->[1]";
		
		$sspcnames{$name->[3]}{'subspecies'} = $name->[4];
		
		if ($mode =~ m/s/) {
			my $val = $name->[5];
			my $found = 0;
			while (!$found) {
				my ($father) = @{request_row("SELECT ref_nom_parent from noms where index = $val", $dbc)};
				
				unless ($father) { $found = 1; }
				else { $val = $father; }
			}
			($sspcnames{$name->[3]}{'genus'}) = @{request_row("SELECT orthographe from noms where index = $val", $dbc)};
		}
		
		#Get previous and next id
		my ( $previous_id, $prev_name, $prev_autority, $next_id, $next_name, $next_autority, $stop, $current_id, $current_name, $current_authority );
		$dbc->{RaiseError} = 1;
		my $sth2 = $dbc->prepare( "SELECT t.index, nc.orthographe, nc.autorite
								FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
								LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
								LEFT JOIN noms AS n ON txn.ref_nom = n.index
								LEFT JOIN statuts AS s ON txn.ref_statut = s.index
								LEFT JOIN rangs AS r ON t.ref_rang = r.index
								WHERE (r.en = 'subspecies' OR r.en = 'species') AND s.en = 'valid'
								ORDER BY nc.orthographe;" );
		$sth2->execute( );
		$sth2->bind_columns( \( $current_id, $current_name, $current_authority ) );
		while ( $sth2->fetch() ){
			if ( $stop ){
				( $next_id, $next_name, $next_autority ) = ( $current_id, $current_name, $current_authority );
				last;
			}
			else {
				if ( $current_id == $subspecies_id ){
					$stop = 1;
				}
				else {
					( $previous_id, $prev_name, $prev_autority ) = ( $current_id, $current_name, $current_authority );
				}
			}
		}
		$sth2->finish(); # finalize the request

		my $up;
		if ($dbase ne 'cool' and $dbase ne 'flow' and $dbase ne 'flow2' and $dbase ne 'strepsiptera') {
			$up = 	div({-class=>'navup'}, 
					$totop, span({-class=>'navarrow'},' > '),
					makeup('speciess', $trans->{'speciess'}->{$lang}, lc(substr($ssp_name, 0, 1)))
				);
		}
				
		if ($dbase eq 'flow' or $dbase eq 'flow2' or $dbase eq 'cipa' or $dbase eq 'strepsiptera') {
			$up .=  div({-class=>'navup'}, 
					prev_next_card( $card, $previous_id, i($prev_name) . " $prev_autority", $next_id, i($next_name) ." $next_autority" )
				);
		}
		
		# fetch species synonyms
		my @names_index;
		push(@names_index, $name->[3]);
		my $names_list = request_tab("SELECT nc.index, nc.orthographe, nc.autorite, s.en, txn.ref_publication_utilisant, txn.ref_publication_denonciation,
						txn.exactitude, txn.completude, txn.exactitude_male, txn.completude_male, txn.exactitude_femelle, txn.completude_femelle,
						txn.sexes_decrits, txn.sexes_valides, txn.ref_nom_cible, nc2.orthographe, nc2.autorite, s.$lang, n.orthographe, n.ref_nom_parent
						FROM taxons_x_noms AS txn 
						LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						LEFT JOIN noms_complets AS nc2 ON nc2.index = txn.ref_nom_cible
						LEFT JOIN noms AS n ON nc.index = n.index
						LEFT JOIN publications As pubd ON pubd.index = txn.ref_publication_denonciation
						LEFT JOIN publications As pubu ON pubu.index = txn.ref_publication_utilisant
						LEFT JOIN publications As pubo ON pubo.index = nc.ref_publication_princeps
						WHERE txn.ref_taxon = $subspecies_id AND s.en not in ('valid', 'dead end') ORDER BY pubd.annee, n.annee, n.parentheses, pubu.annee;",$dbc);
		
		my $nomstat;
		my $modal = 1;
		my $display;
		my ( $syn_list, $typos_list, $combi_list, $wid_list, $os_list, $ios_list, $ies_list, $pid_list, $em_list, $ch_list, $hom_list, $nn_list, $np_list, $uk_list );
		my ( $syn_tab, $typos_tab, $combi_tab, $wid_tab, $os_tab, $ch_tab, $hom_tab, $nn_tab, $np_tab, $uk_tab, $ios_tab, $ies_tab, $pid_tab );
		my %chres;
		if ( scalar @{$names_list} != 0 or $display ) {
			
			if ($mode =~ m/s/) {
					
				foreach my $syn ( @{$names_list} ){
					
					unless (exists($sspcnames{$syn->[0]})) {
					
						$sspcnames{$syn->[0]}{'subspecies'} = $syn->[18];
					
						my $val = $syn->[19];
						my $found = 0;
						while (!$found) {
							my ($father) = @{request_row("SELECT ref_nom_parent from noms where index = $val", $dbc)};
							
							unless ($father) { $found = 1; }
							else { $val = $father; }
						}
						($sspcnames{$syn->[0]}{'genus'}) = @{request_row("SELECT orthographe from noms where index = $val", $dbc)};
					}
				}
			}
			
			my $protect = 0;
			foreach my $syn ( @{$names_list} ){
								
				push(@names_index, $syn->[0]);
				if ( $syn->[3] eq 'synonym' or $syn->[3] eq 'junior synonym' ){
					#my $ambiguous = synonymy( $syn->[6], $syn->[8], $syn->[10] );
					#my $complete = completeness( $syn->[7], $syn->[9], $syn->[11] );
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $sl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$sl .= " $syn->[17] $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
					if ($pub_den[1]) { 
						$sl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]" );
						$sl .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $sl) }
					elsif ($modal == 2) { $syn_list .= li({-class=>'exploli'}, $sl) }
				}
				elsif ( $syn->[3] eq 'wrong spelling' ){
					my @pub_use = publication($syn->[4], 0, 1, $dbc );
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $wsl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$wsl .= " $syn->[17] $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
					if ($pub_use[1]) { 
						$wsl .= " $trans->{'dansin'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]" );
						$wsl .= getPDF($syn->[4]);
					}
					if ($pub_den[1]) { 
						$wsl .= " $trans->{'corrby'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]" );
						$wsl .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $wsl) }
					elsif ($modal == 2) { $typos_list .= li({-class=>'exploli'}, $wsl) }
				}
				elsif ( $syn->[3] eq 'previous combination' ){
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $tl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]");
					$tl .= " $syn->[17] $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
					if ($pub_den[1]) { 
						$tl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]" );
						$tl .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $tl) }
					elsif ($modal == 2) { $combi_list .= li({-class=>'exploli'}, $tl) }
				}
				elsif ( $syn->[3] eq 'misidentification' ){
					my @pub_use = publication($syn->[4], 0, 1, $dbc );
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $mil .= a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2] $syn->[17]" );
					if ($pub_use[1]) { 
						$mil .= " $trans->{'dansin'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]" );
						$mil .= getPDF($syn->[4]);
					}
					if ($pub_den[1]) {
					       	$mil .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]" );
						$mil .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $mil) }
					elsif ($modal == 2) { $wid_list .= li({-class=>'exploli'}, $mil) }
				}
				elsif ( $syn->[3] eq 'previous identification' ){
				
					my @pub_use = publication($syn->[4], 0, 1, $dbc );
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $pil .= a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$pil .= " $trans->{'misid'}->{$lang} $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
					if ($pub_use[1]) { 
						$pil .= " $trans->{'dansin'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]" );
						$pil .= getPDF($syn->[4]);
					}
					if ($pub_den[1]) { 
						$pil .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]" );
						$pil .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $pil) }
					elsif ($modal == 2) { $pid_list .= li({-class=>'exploli'}, $pil) }
				}
				elsif ( $syn->[3] eq 'incorrect original spelling' ){
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $iol = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$iol .= " $syn->[17] $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
					if ($pub_den[1]) { 
						$iol .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]" );
						$iol .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $iol) }
					elsif ($modal == 2) { $ios_list .= li({-class=>'exploli'}, $iol) }
				}
				elsif ( $syn->[3] eq 'incorrect subsequent spelling' ){
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $iel = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$iel .= " $syn->[17] $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
					if ($pub_den[1]) { 
						$iel .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]" );
						$iel .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $iel) }
					elsif ($modal == 2) { $ies_list .= li({-class=>'exploli'}, $iel) }
				}
				elsif ( $syn->[3] eq 'correct use' ){
					
					my @pub_use = publication($syn->[4], 0, 1, $dbc );
					
					unless (exists $chres{$syn->[0]}) { 
						$chres{$syn->[0]} = {};
						$chres{$syn->[0]}{'label'} = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, 
						i($syn->[1]) . " $syn->[2]" ) . " $trans->{'cited_in'}->{$lang} ";
						
						$chres{$syn->[0]}{'refs'} = ();
						push(@{$chres{$syn->[0]}{'refs'}}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]" ) . getPDF($syn->[4]));
					}
					else {
						push(@{$chres{$syn->[0]}{'refs'}}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]" ) . getPDF($syn->[4]));						
					}
				}
				elsif ( $syn->[3] eq 'homonym' ){
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $hl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$hl .= " $syn->[17] $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
					if ($pub_den[1]) { 
						$hl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]" );
						$hl .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $hl) }
					elsif ($modal == 2) { $hom_list .= li({-class=>'exploli'}, $hl) }
				}
				elsif ( $syn->[3] eq 'nomen nudum' ){
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $nl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$nl .=  " " . i($syn->[17]) . " $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
					if ($pub_den[1]) { 
						$nl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]" );
						$nl .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $nl) }
					elsif ($modal == 2) { $nn_list .= li({-class=>'exploli'}, $nl) }
				}
				elsif ( $syn->[3] eq 'status revivisco' or $syn->[3] eq 'combinatio revivisco' ){
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $nl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$nl .=  " " . i($syn->[17]);
					if ($syn->[1] ne $syn->[15] or $syn->[2] ne $syn->[16]) { $nl .= " $trans->{'toen'}->{$lang} " . i($syn->[15]) . " $syn->[16]"; }
					if ($pub_den[1]) { 
						$nl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]" );
						$nl .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $nl) }
					elsif ($modal == 2) { $nn_list .= li({-class=>'exploli'}, $nl) }
				}
				elsif ( $syn->[3] eq 'nomen praeoccupatum' ){
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $npl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$npl .= " " . i($syn->[17]) . " $trans->{'fromto'}->{$lang} " . i($syn->[15]) . " $syn->[16] " . i($trans->{'nnov'}->{$lang});
					if ($pub_den[1]) { 
						$npl .= ", $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]" );
						$npl .= getPDF($syn->[5]);
					}
					if ($syn->[14] eq $name->[3] and 0) { $nomstat .= '&nbsp; ' . i($trans->{'nnov'}->{$lang}) }
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $npl) }
					elsif ($modal == 2) { $np_list .= li({-class=>'exploli'}, $npl) }
				}
				elsif ( $syn->[3] eq 'nomen oblitum' ){
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $npl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$npl .= " " . i($syn->[17]) . ", $trans->{'synonym'}->{$lang} $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16] " . i($trans->{'nprotect'}->{$lang});
					if ($pub_den[1]) { 
						$npl .= ", $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]" );
						$npl .= getPDF($syn->[5]);
					}
					if ($syn->[14] eq $name->[3] and !$protect) { $nomstat .= '&nbsp; ' . i($trans->{'nprotect'}->{$lang}); $protect = 1; }
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $npl) }
					elsif ($modal == 2) { $np_list .= li({-class=>'exploli'}, $npl) }
				}
				elsif ( $syn->[15] eq 'outside taxon' ){
					my $npl = i($syn->[1]) . " $syn->[2]";
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $npl) }
				}
				else {
					my @pub_den = publication($syn->[5], 0, 1, $dbc );
					my $ukl = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . " $syn->[2]" );
					$ukl .= " $syn->[17] $trans->{'of'}->{$lang} " . i($syn->[15]) . " $syn->[16]";
					if ($pub_den[1]) { 
						$ukl .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]" );
						$ukl .= getPDF($syn->[5]);
					}
					if ($modal == 1) { $display .= li({-class=>'exploli'}, $ukl) }
					elsif ($modal == 2) { $uk_list .= li({-class=>'exploli'}, $ukl) }
				}
			}
			
			foreach (keys %chres) {
				my $cl = $chres{$_}{'label'};
				if ($chres{$_}{'refs'}) { $cl .= join (', ', @{$chres{$_}{'refs'}}); }
				$ch_list .= li({-class=>'exploli'}, $cl);
			}
			
			if ($modal == 2) {
				if ( $syn_list ){
					$syn_tab = h4({-class=>'exploh4'}, $trans->{'synonyms'}->{$lang});
					$syn_tab .= ul({-class=>'exploul'}, $syn_list); 
				}
				if ( $typos_list ){
					$typos_tab = h4({-class=>'exploh4'}, $trans->{'typos'}->{$lang});
					$typos_tab .= ul({-class=>'exploul'}, $typos_list); 
				}
				if ( $combi_list ){
					$combi_tab = h4({-class=>'exploh4'}, $trans->{'ori_coms'}->{$lang});
					$combi_tab .= ul({-class=>'exploul'}, $combi_list); 
				}
				if ( $wid_list ){
					$wid_tab = h4({-class=>'exploh4'}, $trans->{'id_error'}->{$lang});
					$wid_tab .= ul({-class=>'exploul'}, $wid_list); 
				}
				if ( $os_list ){
					$os_tab = h4({-class=>'exploh4'}, $trans->{'other_sex'}->{$lang});
					$os_tab .= ul({-class=>'exploul'}, $os_list); 
				}
				if ( $ch_list ) {
					$ch_tab = h4({-class=>'exploh4'}, $trans->{'Chresonym(s)'}->{$lang});
					$ch_tab .= ul({-class=>'exploul'}, $ch_list);
				}
				if ( $hom_list ) {
					$hom_tab = h4({-class=>'exploh4'}, $trans->{'Homonym(s)'}->{$lang});
					$hom_tab .= ul({-class=>'exploul'}, $hom_list);
				}
				if ( $nn_list ) {
					$nn_tab = h4({-class=>'exploh4'}, i(ucfirst($trans->{'Nomen_nudum'}->{$lang})));
					$nn_tab .= ul({-class=>'exploul'}, $nn_list);
				}
				if ( $np_list ) {
					$np_tab = h4({-class=>'exploh4'}, i(ucfirst($trans->{'Nomen_praeoccupatum'}->{$lang})));
					$np_tab .= ul({-class=>'exploul'}, $np_list);
				}
				if ( $uk_list ) {
					$uk_tab = h4({-class=>'exploh4'}, $trans->{'nom_act(s)'}->{$lang});
					$uk_tab .= ul({-class=>'exploul'}, $uk_list);
				}
				if ( $ios_list ) {
					$ios_tab = h4({-class=>'exploh4'}, $trans->{'ios(s)'}->{$lang});
					$ios_tab .= ul({-class=>'exploul'}, $ios_list);
				}
				if ( $ies_list ) {
					$ies_tab = h4({-class=>'exploh4'}, $trans->{'ies(s)'}->{$lang});
					$ies_tab .= ul({-class=>'exploul'}, $ies_list);
				}
				if ( $pid_list ) {
					$pid_tab = h4({-class=>'exploh4'}, $trans->{'pid(s)'}->{$lang});
					$pid_tab .= ul({-class=>'exploul'}, $pid_list);
				}
				
				$display = $combi_tab.$syn_tab.$hom_tab.$np_tab.$ios_tab.$ies_tab.$nn_tab.$ch_tab.$typos_tab.$wid_tab.$pid_tab.$uk_tab.$os_tab;
			}
			else { 
				if ($display) { $display =  h4({-class=>'exploh4'}, ucfirst($trans->{'synonymie'}->{$lang})) . ul({-class=>'exploul'}, $display); }
				if ( $ch_list ) {
					$ch_tab = h4({-class=>'exploh4'}, $trans->{'Chresonym(s)'}->{$lang});
					$ch_tab .= ul({-class=>'exploul'}, $ch_list);
				}
				$display .= $ch_tab;
			
				if ($dbase eq 'psylles' and !$display) { $display .= br; }
			}
		}
		
		# fetch princeps publication
		my $publication_tab;
		if (  $name->[2] ) {
			$publication_tab = h4({-class=>'exploh4'}, $trans->{"ori_pub"}->{$lang});
			my $pub = pub_formating($name->[2], $dbc );
			$publication_tab .= div({-class=>'pubdiv'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$name->[2]"}, "$pub") . getPDF($name->[2]));
		}
		else {
			#$publication_tab = div({-class=>'pubdiv'}, $trans->{"UNK"}->{$lang});
		}
		
		my $plants = request_tab("SELECT p1.index, p1.nom, p2.nom, p3.nom, txp.ref_publication_ori, txp.certitude, p1.autorite, r.en, p1.statut, p1.ref_valide FROM plantes AS p1 
						LEFT JOIN plantes AS p2 ON (p1.ref_parent = p2.index)
						LEFT JOIN plantes AS p3 ON (p2.ref_parent = p3.index)
						LEFT JOIN taxons_x_plantes AS txp ON (p1.index = txp.ref_plante)
						LEFT JOIN rangs AS r ON p1.ref_rang = r.index
						LEFT JOIN publications AS pub ON pub.index = txp.ref_publication_ori
						WHERE txp.ref_taxon = $subspecies_id
						AND r.en in ('family','genus', 'species')
						ORDER BY p2.nom, p1.nom, p3.nom, pub.annee;",$dbc,2);
						


		my $current;
		my $string;
		my @pubs;
		my $confirm;
		my $tabpl;
		if ( scalar @{$plants} ){
			foreach my $row ( @{$plants} ){
				my $pdisp;
			        if ("$row->[0]/$row->[5]" ne $current) {
					if ($current) {
						if (scalar(@pubs)) { $string .= "&nbsp; $trans->{'segun'}->{$lang} &nbsp;" . join(', ', @pubs);  }
						$tabpl .= li({-class=>'exploli'}, "$string $confirm");
					}
					
					$current = "$row->[0]/$row->[5]";
					@pubs = ();
					$confirm = '';
					
					if ($row->[3]) { 
						$string = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plant&id=$row->[0]"}, i("$row->[2] $row->[1]") . " $row->[6] ($row->[3])"); 
					}
					elsif ($row->[2]) { $string = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plant&id=$row->[0]"}, i($row->[1]) . " $row->[6] ($row->[2])") }
					else { $string = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plant&id=$row->[0]"}, $row->[1]) }
				}

				if ($row->[4]) {
					my @p = publication($row->[4], 0, 1, $dbc);
					push(@pubs, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$row->[4]"}, $p[1]) . getPDF($row->[4]));
				}
				
				if ($row->[5] eq 'uncertain') { $confirm = "&nbsp; [ $trans->{'doubtful'}->{$lang} ]"; }
				elsif ($row->[5] eq 'certain') { $confirm = "&nbsp; [&nbsp;$trans->{'confirmed'}->{$lang}&nbsp;]"; }
			}

			if (scalar(@pubs)) { $string .= "&nbsp; $trans->{'segun'}->{$lang} &nbsp;" . join(', ', @pubs);  }
			
			if ($plants->[$#{$plants}][5] eq 'uncertain') { $confirm = "&nbsp; [ $trans->{'doubtful'}->{$lang} ]"; }
			elsif ($plants->[$#{$plants}][5] eq 'certain') { $confirm = "&nbsp; [&nbsp;$trans->{'confirmed'}->{$lang}&nbsp;]"; }

			$tabpl .= li({-class=>'exploli'}, "$string $confirm");
			
			my $espace;
			if (!$display and $dbase eq 'psylles') { $espace = br; }
			
			$tabpl = 	$espace.
					div({-id=>'pltdisp',	-class=>'disparrow',
								-style=>'display: block; float: left;',
								-onMouseOver=>  "document.getElementById('pltdisp').style.cursor = 'pointer';",
								-onClick=>"	document.getElementById('pltdisp').style.display = 'none';
										document.getElementById('plthide').style.display = 'block';
										document.getElementById('plantsdiv').style.display = 'block';"}, '&nbsp;') . 
					div({-id=>'plthide',	-class=>'hidearrow',
								-style=>'display: none; float: left;',
								-onMouseOver=>  "document.getElementById('plthide').style.cursor = 'pointer';",
								-onClick=>"	document.getElementById('plthide').style.display = 'none';
										document.getElementById('pltdisp').style.display = 'block';
										document.getElementById('plantsdiv').style.display = 'none';"}, '&nbsp;') . 
					h4({-class=>'exploh4',	-style=>'display: inline; margin-left: 6px;',
								-onMouseOver=>  "this.style.cursor = 'pointer';",
								-onClick=>"	if (	document.getElementById('plantsdiv').style.display == 'block') {
											document.getElementById('plthide').style.display = 'none';
											document.getElementById('pltdisp').style.display = 'block';
											document.getElementById('plantsdiv').style.display = 'none';
										}
										else{
											document.getElementById('pltdisp').style.display = 'none';
											document.getElementById('plthide').style.display = 'block';
											document.getElementById('plantsdiv').style.display = 'block';
										}"}, 
										$trans->{"hostplant(s)"}->{$lang}) . p .
					div({-id=>'plantsdiv', -style=>'display: none;'}, ul({-class=>'exploul'}, $tabpl));
		}
		
		my $regions = [];
	       
		if ($dbase ne 'cipa') {
			$regions = request_tab("SELECT r.index, r.nom
			FROM regions_biogeo AS r LEFT JOIN taxons_x_regions_biogeo AS txr ON (r.index = txr.ref_region_biogeo)
			WHERE txr.ref_taxon = $subspecies_id;",$dbc);
		}
		
		my $vdisplay = get_vernaculars($dbc, 'txv.ref_taxon', $subspecies_id);

		my $tabr;
		if ( scalar @{$regions} ){
			foreach my $row ( @{$regions} ){
				$tabr .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=region&id=$row->[0]"}, "$row->[1]") );
			}
			$tabr = h4({-class=>'exploh4'}, $trans->{"region_as"}->{$lang}) . ul({-class=>'exploul'}, $tabr);
		}
		
		# fetch images
		my $imagesurl;
		my $images = request_tab("SELECT icone_url, index, url FROM taxons_x_images AS txi LEFT JOIN images AS I ON txi.ref_image = I.index WHERE txi.ref_taxon = $subspecies_id;",$dbc);
		
		my $images_types = [];
		$images_types = request_tab("	SELECT icone_url, I.index, url, nc.orthographe, nc.autorite
							FROM noms_x_images AS nxi 
							LEFT JOIN images AS I ON nxi.ref_image = I.index 
							LEFT JOIN noms_complets AS nc ON nxi.ref_nom = nc.index
							WHERE nxi.ref_nom in (".join(',', @names_index).");",$dbc);
		
		my $default_img_display = 'none';
		if ($dbase eq 'cool') { $default_img_display = 'block'; }
		
		if ( scalar @{$images} != 0 or scalar @{$images_types} != 0 ){
			$imagesurl = 	span({-id=>'imgdisp',	-class=>'disparrow',
								-style=>'display: block; float: left;',
								-onMouseOver=>  "document.getElementById('imgdisp').style.cursor = 'pointer';",
								-onClick=>"	document.getElementById('imgdisp').style.display = 'none';
										document.getElementById('imghide').style.display = 'block';
										document.getElementById('imgsdiv').style.display = 'block';"}, '&nbsp;') . 
					span({-id=>'imghide',	-class=>'hidearrow',
								-style=>'display: none; float: left;',
								-onMouseOver=>  "document.getElementById('imghide').style.cursor = 'pointer';",
								-onClick=>"	document.getElementById('imghide').style.display = 'none';
										document.getElementById('imgdisp').style.display = 'block';
										document.getElementById('imgsdiv').style.display = 'none';"}, '&nbsp;') .
					h4({-class=>'exploh4', 	-style=>'display: inline; margin-left: 6px;',
								-onMouseOver=>  "this.style.cursor = 'pointer';",
								-onClick=>"	if (	document.getElementById('imgsdiv').style.display == 'block') {
											document.getElementById('imghide').style.display = 'none';
											document.getElementById('imgdisp').style.display = 'block';
											document.getElementById('imgsdiv').style.display = 'none';
										}
										else{
											document.getElementById('imgdisp').style.display = 'none';
											document.getElementById('imghide').style.display = 'block';
											document.getElementById('imgsdiv').style.display = 'block';
										}"}, 
										ucfirst($trans->{'img(s)'}->{$lang}))  . p;
					

			$imagesurl .= "<DIV ID=imgsdiv STYLE='display: $default_img_display; float: none;'>";
			if ($dbase eq 'cool') {
				foreach my $row ( @{$images} ){
					$imagesurl .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"window.open('$row->[2]', '', 'toolbar=0, location=0, scrollbars=1, directories=0, status=0, resizable=1, width=1100, height=800');"}, img({-src=>"$row->[0]", -style=>'border: 0; margin: 0;'})));
				}
				foreach my $row ( @{$images_types}){
					$imagesurl .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"window.open('$row->[2]', '', 'toolbar=0, location=0, scrollbars=1, directories=0, status=0, resizable=1, width=1100, height=800');"}, img({-src=>"$row->[0]", -style=>'border: 0; margin: 0;'})));
				}				
			}
			else {
				foreach my $row ( @{$images} ){
					$imagesurl .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=image&id=$row->[1]&search=taxon"}, img({-src=>"$row->[0]", -style=>'border: 0; margin: 0;'})));
				}
				foreach my $row ( @{$images_types}){
					$imagesurl .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=image&id=$row->[1]&search=nom"}, img({-src=>"$row->[0]", -style=>'border: 0; margin: 0;'})));
				}
			}
			$imagesurl .= '</DIV>' . div({-style=>'clear: both; float: none;'});
		}

		# Fetch presence of the species in a country
		my $countries_list = '';
		$dbc->{RaiseError} = 1;
		
		my $sth5 = $dbc->prepare( "SELECT ref_pays, p.$lang, p.en, p.tdwg, p.tdwg_level, p.parent, ref_publication_ori
						FROM taxons_x_pays AS txp 
						LEFT JOIN pays AS p ON txp.ref_pays = p.index
						LEFT JOIN publications  AS pub ON pub.index = ref_publication_ori
						WHERE txp.ref_taxon = $subspecies_id and p.en != 'Unknown'
						ORDER  BY p.$lang, pub.annee;" );

		$sth5->execute( );
		my ( $country_id, $country, $en, $tdwg, $level, $parent, $ref_pub_ori );
		$sth5->bind_columns( \( $country_id, $country, $en, $tdwg, $level, $parent, $ref_pub_ori ) );
		
		my $current;
		my $string;
		my @pubs;
		my $sup = 'NULL';
		my (@tdwg2, @tdwg3, @tdwg4);
		my %tgdone;
		my %level1;
		while ( $sth5->fetch ) {
				my $pdisp;
			        if ($country_id != $current) {
					if ($current) {
						if (scalar(@pubs)) { $string .= "&nbsp; $trans->{'segun'}->{$lang} &nbsp;" . join(', ', @pubs);  }
						$countries_list .= li({-class=>'exploli'}, "$string");
					}
					$current = $country_id;
					@pubs = ();
					my $sep;
					if ($country =~ m/$sup \(/) { $sep = '&nbsp;&nbsp;&nbsp;' } else { $sup = $country }
					$string = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=$current"}, $sep . $country);
				}
					
				if ($ref_pub_ori) {
					my @p = publication($ref_pub_ori, 0, 1, $dbc);
					push(@pubs, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$ref_pub_ori"}, $p[1]) . getPDF($ref_pub_ori));
				}
				
				#if ($level eq '1') { $level1{$tdwg} = 1; }
				#elsif ($level eq '2') { 
				#	if ($parent) {
				#		$level1{$parent} = 1;
				#	}
				#}
				#elsif ($level eq '3') { 
				#	if ($parent) {
				#		my ($l1) = @{request_row("SELECT parent FROM pays WHERE tdwg = '$parent';", $dbc)};
				#		$level1{$l1} = 1;
				#	}
				#}
				#elsif ($level eq '4') { 
				#	if ($parent) {
				#		my ($l1) = @{request_row("SELECT parent FROM pays WHERE tdwg = (SELECT parent FROM pays WHERE tdwg = '$parent');", $dbc)};
				#		$level1{$l1} = 1;
				#	}
				#}
#				unless (exists $tgdone{$tdwg}) {
#					
#					if ($level eq '2') {
#						push(@tdwg2, $tdwg);
#					}
#					elsif ($level eq '3') {
#						push(@tdwg3, $tdwg);
#					}
#					elsif ($level eq '4') {
#						push(@tdwg4, $tdwg);
#					}
#					else { unless ($en eq 'Unknown') { die "Country $country has no valid tdwg level !!" } }
#					
#					$tgdone{$tdwg} = 1;
#				}
				
				unless (exists $tgdone{$tdwg.'/'.$en}) {
					
					my @fathers;
					
					if (length($tdwg) >= 5) { 
						
						if ($parent) {
							my ($father) = request_row("SELECT en FROM pays WHERE tdwg = '$parent';",$dbc,1);
							if ($father eq $en) { push(@fathers, $parent) }
							else { push(@tdwg4, $tdwg); }
						}
						else {
							push(@tdwg4, $tdwg);
						}
					} else {
						push(@fathers, $tdwg);
					}
					
					while (scalar(@fathers)) {
						my $sons = request_tab("SELECT tdwg FROM pays WHERE parent IN ('" . join("', '",@fathers) . "');",$dbc,1);
						
						@fathers = ();
						
						if (scalar(@{$sons})) {
							foreach (@{$sons}) {
								if (length($_) >= 5) { 
									push(@tdwg4, $_); 
								}
								else { push(@fathers, $_); }
							}
						}
					}
					$tgdone{$tdwg.'/'.$en} = 1;
				}

		}
		
		if (scalar(@pubs)) { $string .= "&nbsp; $trans->{'segun'}->{$lang} &nbsp;" . join(', ', @pubs);  }
		if ($string) { $countries_list .= li({-class=>'exploli'}, "$string"); }
			
		#while ( $sth5->fetch ) {
		#	my $altitude = '';
		#	( $altitude_min or $altitude_max ) ? ( $altitude = " ($altitude_min m, $altitude_max m)" ) : ( $altitude = '' );
		#	( $altitude_min_min or $altitude_max_max ) ? ( $altitude .= " (min: $altitude_min_min m, max: $altitude_max_max m)" ) : ( $altitude .= '' );
		#	( $epoque_abondance ) ? ( $altitude .= " $epoque_abondance" ) : ( $altitude .= '' );
		#}
		
		$sth5->finish();
		my $map;
		my $areas;
		if ( $countries_list ){
			$countries_list =   div({-class=>'mapdiv'},
						span({-id=>'ctrdisp',	-class=>'disparrow',
									-style=>'display: block; float: left;',
									-onMouseOver=>  "document.getElementById('ctrdisp').style.cursor = 'pointer';",
									-onClick=>"	document.getElementById('ctrdisp').style.display = 'none';
											document.getElementById('ctrhide').style.display = 'block';
											document.getElementById('paysdiv').style.display = 'block';"}, '') . 
						span({-id=>'ctrhide',	-class=>'hidearrow',
									-style=>'display: none; float: left;',
									-onMouseOver=>  "document.getElementById('ctrhide').style.cursor = 'pointer';",
									-onClick=>"	document.getElementById('ctrhide').style.display = 'none';
											document.getElementById('ctrdisp').style.display = 'block';
											document.getElementById('paysdiv').style.display = 'none';"}, '') . 
						h4({-class=>'exploh4',	-id=>'cttitle',
									-style=>'display: inline; margin-left: 6px;',
									-onMouseOver=>  "this.style.cursor = 'pointer';",
									-onClick=>"	if (document.getElementById('paysdiv').style.display == 'block') {
												document.getElementById('ctrhide').style.display = 'none';
												document.getElementById('ctrdisp').style.display = 'block';
												document.getElementById('paysdiv').style.display = 'none';
											}
											else{
												document.getElementById('ctrdisp').style.display = 'none';
												document.getElementById('ctrhide').style.display = 'block';
												document.getElementById('paysdiv').style.display = 'block';
											}"}, 
											$trans->{"geodistribution"}->{$lang}) . p .
						div({-id=>'paysdiv', -style=>'display: none;'}, ul({-class=>'exploul'}, $countries_list)));
						
						my $bgsea;
						my $bgearth;
						my $bdearth;
						my $cclr;
						my $cdbr;
						my $wdth;
						
						if ($dbase eq 'psylles') { 
							$bgsea = '000000';
							$bgearth = '282828';
							$bdearth = '282828';
							$cclr = '99dd44';
							$cdbr = '99dd44';
							$wdth = 700 
						}
						elsif ($dbase eq 'cool') { 
							$bgsea = '8D1610';
							$bgearth = '650C06';
							$bdearth = '650C06';
							$cclr = 'FFCC66';
							$cdbr = 'EEBB55';
							$wdth = 500 
						}
						elsif ($dbase eq 'flow' or $dbase eq 'flow2') { 
							$bgsea = '';
							$bgearth = 'BBBBBB';
							$bdearth = 'DDDDDD';
							$cclr = '000066';
							$cdbr = 'DDDDDD';
							$wdth = 700 
						}
						else { 
							$bgsea = '';
							$bgearth = 'CCCCCC';
							$bdearth = 'CCCCCC';
							$cclr = '0F5286';
							$cdbr = '0F5286';
							$wdth = 500 
						}
						
						my $mapok;
						if (scalar(@tdwg4)) {
							$areas .= 'tdwg4:a:'.join(',', @tdwg4).'||';
							$mapok = 1;
						}
						if (scalar(@tdwg3)) {
							$areas .= 'tdwg3:a:'.join(',', @tdwg3).'||';
							$mapok = 1;
						}
						if (scalar(@tdwg2)) {
							$areas .= 'tdwg2:a:'.join(',', @tdwg2).'||';
							$mapok = 1;
						}
						#if (scalar(keys(%level1)) == 0) {} else { my ($key) = keys(%level1); if ($key == 6) { $mapok = 0; } $areas .= "tdwg1:b:$key"; }
						if ($bgearth eq $bdearth) {
							$areas .= "tdwg1:b:1,2,3,4,5,6,7,8,9";
						}
						else {
							$areas = substr($areas,0,-2);
							$areas = "tdwg4:b:".join(',',@{request_tab("SELECT tdwg FROM pays WHERE tdwg_level = '4' AND parent IN (SELECT tdwg FROM pays WHERE tdwg_level = '3');", $dbc, 1)})."||$areas";
						}
						$areas = "ad=$areas";
						
						my $styles = "as=a:$cclr,$cdbr,0|b:$bgearth,$bdearth,0";
						
						if ($mapok) {
							$map = "
							<script type='text/javascript'>
							function ImageMax(chemin) {
								var html = '<html> <head> <title>Distribution</title> </head> <body style=\"background: #$bgsea;\"><IMG style=\"background: #$bgsea;\" src='+chemin+' BORDER=0 NAME=ImageMax></body></html>';
								var popupImage = window.open('','_blank','toolbar=0, location=0, scrollbars=0, directories=0, status=0, resizable=1, width=1020, height=520');
								popupImage.document.open();
								popupImage.document.write(html);
								popupImage.document.close()
							};
							</script>
								<img id='cmap' style='background: #$bgsea;' src='$maprest?$areas&$styles&ms=$wdth' onMouseOver=\"this.style.cursor='pointer';\"  onclick=\"ImageMax($maprest?$areas&$styles&ms=1000');\">". br. br;
						}
		}
		
		
		my $ua = LWP::UserAgent->new;
		$ua->agent("MNHNspec");
		
		my $speclinks;
		my $separator;
		if ($dbase eq 'flow' or $dbase eq 'flow2') { $separator = hr({-class=>'spec_separator'}); }
		
		if ($mode =~ m/s/) {
			foreach (keys(%sspcnames)) {
				
				my $link = "http://coldb.mnhn.fr/ScientificName/" . $sspcnames{$_}{'genus'} . '/' . $sspcnames{$_}{'species'};
				
				my $req = HTTP::Request->new(GET => $link);
			
				my $res = $ua->request($req);
			
				if ($res->is_success) {
					
					$speclinks .= 	br. $separator.
							a({-class=>'exploa', -href=>$link, -target=>'_blank'}, $trans->{'mnhn_spec_of'}->{$lang} . ' ' . $sspcnames{$_}{'genus'} . ' ' . $sspcnames{$_}{'species'} ) . br;
				}
			}
			
			unless ($speclinks) { $speclinks = $trans->{'no_mnhn_spec'}->{$lang}; }
			
			$speclinks = h4({-class=>'exploh4'}, $trans->{'mnhn_spec'}->{$lang}) . $speclinks . p;
		}
		elsif ($dbase ne 'cipa' and $dbase ne 'strepsiptera') { 
			my @params;
			foreach (keys(%labels)) { if ($labels{$_}) { push(@params, $_) } }
			my $args = join('&', map { "$_=$labels{$_}"} @params );
			
			$mode .= 's';

			$speclinks = 	br. $separator.
					h4({-class=>'exploh4'}, $trans->{'mnhn_spec'}->{$lang}) . a({-class=>'exploa', -href=>"$scripts{$dbase}$args&mode=$mode"}, $trans->{'check_mnhn_spec'}->{$lang}) . p;
		}
		
		if ($dbase eq 'cool') { $countries_list = br . $countries_list; }
		
		unless($display) { $display = br; }
		
		$fullhtml = 	div({-class=>'explocontent'},
					$up,
					div({-class=>'hierarchy'},
						a({-class=>'navlink', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=genus&id=$genus_id"}, $genus_fullname ),
						span({-class=>'navarrow'},' > '),
						a({-class=>'navlink', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$species_id"}, $species_fullname ),
						#' > ',
						#$ssp_tab, p,
					),
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{'subspecies'}->{$lang} ), 
						a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=subspecies&id=$subspecies_id"},
							span({-class=>'subject', -style=>'display: inline;'}, $ssp_tab )
						), $nomstat, br,
						$publication_tab,
						$display,
						$tabpl,
						$tabr,
						$countries_list,
						$map,
						$imagesurl,
						$vdisplay,
						$speclinks
					)
				);
				
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
		my $name = request_row("SELECT nc.orthographe, nc.autorite, nc.ref_publication_princeps, n.page_princeps FROM noms_complets AS nc LEFT JOIN noms AS n ON n.index = nc.index WHERE nc.index = $name_id;",$dbc);

		my $taxa = request_tab("SELECT txn.ref_taxon, s.en, txn.ref_publication_utilisant, txn.ref_publication_denonciation, txn.exactitude,
					txn.completude, txn.exactitude_male, txn.completude_male, txn.exactitude_femelle, 
					txn.completude_femelle, txn.sexes_decrits, txn.sexes_valides, txn.ref_nom_cible, s.$lang, r.en, r2.en, txn.page_denonciation, txn.page_utilisant
					FROM taxons_x_noms AS txn 
					LEFT JOIN taxons AS t ON t.index = txn.ref_taxon
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN rangs AS r ON r.index = t.ref_rang
					LEFT JOIN rangs AS r2 ON r2.index = (select ref_rang from noms_complets where index = txn.ref_nom)
					LEFT JOIN publications AS p1 ON p1.index = txn.ref_publication_utilisant
					LEFT JOIN publications AS p2 ON p2.index = txn.ref_publication_denonciation
					WHERE txn.ref_nom = $name_id
					AND s.en not in ('correct use', 'status revivisco')
					ORDER BY p1.annee, p2.annee;",$dbc);

		if (scalar(@{$taxa}) == 1 and $taxa->[0][1] eq 'valid') {
			$dbc->disconnect;
			$id = $taxa->[0][0];
			$rank = $taxa->[0][14];
			if ($rank eq 'family') { family_card(); }
			elsif ($rank eq 'genus') { genus_card(); }
			elsif ($rank eq 'subgenus') { subgenus_card(); }
			elsif ($rank eq 'species') { species_card(); }
			elsif ($rank eq 'subspecies') { subspecies_card(); }
		}
		else {
			#Get previous and next id
			my ( $previous_id, $prev_name, $prev_autority, $next_id, $next_name, $next_autority, $stop, $current_id, $current_name, $current_autority );
			$dbc->{RaiseError} = 1;
	
			my $sth2 = $dbc->prepare( "SELECT n.index, orthographe, autorite FROM taxons_x_noms AS txn
							LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
							LEFT JOIN statuts AS s ON txn.ref_statut = s.index
							LEFT JOIN rangs AS r ON n.ref_rang = r.index
							WHERE r.en = 'order' OR r.en = 'suborder'
							OR r.en = 'family' OR r.en = 'subfamily'
							OR r.en = 'genus' OR r.en = 'subgenus'
							OR r.en = 'super species' OR r.en = 'species' OR r.en LIKE '%'||'subspecies'
							GROUP BY n.index, orthographe, autorite, r.ordre ORDER BY r.ordre, LOWER ( orthographe );" );
			$sth2->execute( );
			$sth2->bind_columns( \( $current_id, $current_name, $current_autority ) );
			while ( $sth2->fetch() ){
				if ( $stop ){
					( $next_id, $next_name, $next_autority ) = ( $current_id, $current_name, $current_autority );
					last;
				}
				else {
					if ( $current_id == $name_id ){
						$stop = 1;
					}
					else {
						( $previous_id, $prev_name, $prev_autority ) = ( $current_id, $current_name, $current_autority );
					}
				}
			}
			$sth2->finish();
	
			my $up;
			if ($dbase ne 'cool' and $dbase ne 'flow' and $dbase ne 'flow2' and $dbase ne 'strepsiptera') {
				$up = 	div({-class=>'navup'}, $totop . ' > ' . makeup('names', $trans->{'names'}->{$lang}, lc(substr($name->[0], 0, 1))));
			}
	
			#my $up = prev_next_card( $card, $previous_id, i($prev_name) . " $prev_autority", $next_id, i($next_name) . " $next_autority" );
	
			# Fetch princeps publication of the name
			my $ori_pub;
			if ( $name->[2] ) {
				$ori_pub = h4({-class=>'exploh4'}, $trans->{'ori_pub'}->{$lang}); 
				my $pub = pub_formating($name->[2], $dbc, $name->[3]);
				$ori_pub .= ul({-class=>'exploul'}, li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$name->[2]"}, "$pub") . getPDF($name->[2])));
			}
			else {
				#$ori_pub = ul({-class=>'exploul'}, li({-class=>'exploli'}, $trans->{"UNK"}->{$lang}));
			}
			
			my $taxa_tab;
			my @chresos;
			my %done;
			foreach my $taxon ( @{$taxa} ){
				
				my $tax_name;
				if ($taxon->[12]) {
					$tax_name = request_row("	SELECT nc.orthographe, nc.autorite 
									FROM noms_complets AS nc
									WHERE index = $taxon->[12];",$dbc); 
				}
				if ( $taxon->[1] eq 'synonym' or $taxon->[1] eq 'junior synonym'){
					
					my $ambiguous = synonymy( $taxon->[4], $taxon->[6], $taxon->[8] );
					my $complete = completeness( $taxon->[5], $taxon->[7], $taxon->[9] );
					
					my $tt = "$taxon->[13] $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$taxon->[14]&id=$taxon->[0]"}, i($tax_name->[0]) . " $tax_name->[1]" );
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}
	
					$taxa_tab .= li({-class=>'exploli'}, $tt);
				}
				elsif ( $taxon->[1] eq 'wrong spelling'){
					
					my @pub_use = publication($taxon->[2], 0, 1, $dbc );
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					my $tt = "$taxon->[13] $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$taxon->[14]&id=$taxon->[0]"}, i($tax_name->[0]) . " $tax_name->[1]" );
					if ($pub_use[1]) { 
						if ($taxon->[17]) { $taxon->[17] = ": ".$taxon->[17]; }
						$tt .= " $trans->{'dansin'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[2]"}, "$pub_use[1]".$taxon->[17] ); 
						$tt .= getPDF($taxon->[2]);
					}
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}
					$taxa_tab .= li({-class=>'exploli'}, $tt );
				}
				elsif ( $taxon->[1] eq 'previous identification'){
					
					my @pub_use = publication($taxon->[2], 0, 1, $dbc );
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					my $tt = "$trans->{'misid'}->{$lang} $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$taxon->[14]&id=$taxon->[0]"}, i($tax_name->[0]) . " $tax_name->[1]" );
					if ($pub_use[1]) { 
						if ($taxon->[17]) { $taxon->[17] = ": ".$taxon->[17]; }
						$tt .= " $trans->{'dansin'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[2]"}, "$pub_use[1]".$taxon->[17] ); 
						$tt .= getPDF($taxon->[2]);
					}
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}
					$taxa_tab .= li({-class=>'exploli'}, $tt );
				}
				elsif ( $taxon->[1] eq 'previous combination' ){
					
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					my $tt = "$taxon->[13] $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$taxon->[14]&id=$taxon->[0]"}, i($tax_name->[0]) . " $tax_name->[1]" );
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}
					$taxa_tab .= li({-class=>'exploli'}, $tt);
				}
				elsif ( $taxon->[1] eq 'misidentification' ){
					
					my $test = request_tab("SELECT count(*) from taxons_x_noms WHERE ref_nom = $name_id and ref_statut = 18",$dbc);
					
					unless ($test->[0][0]) {
					
						my @pub_use = publication($taxon->[2], 0, 1, $dbc );
						my @pub_den = publication($taxon->[3], 0, 1, $dbc );
						my $tt = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$taxon->[14]&id=$taxon->[0]"}, "$taxon->[13]" );
						if ($pub_use[1]) { 
							if ($taxon->[17]) { $taxon->[17] = ": ".$taxon->[17]; }
							$tt .= " $trans->{'dansin'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[2]"}, "$pub_use[1]".$taxon->[17] ); 
							$tt .= getPDF($taxon->[2]);
						}
						if ($pub_den[1]) { 
							if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
							$tt .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] ); 
							$tt .= getPDF($taxon->[2]);
						}
						$taxa_tab .= li({-class=>'exploli'}, $tt);
					}
				}
				elsif ( $taxon->[1] eq 'valid' ){
					$taxa_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$taxon->[15]&id=$taxon->[0]"}, "$taxon->[13]"));
				}
				elsif ( $taxon->[1] eq 'incorrect original spelling' or $taxon->[1] eq 'incorrect subsequent spelling' ){
					
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					my $tt = "$taxon->[13] $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$taxon->[14]&id=$taxon->[0]"}, i($tax_name->[0]) . " $tax_name->[1]" );
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}
					$taxa_tab = li({-class=>'exploli'}, $tt );
				}
				elsif ( $taxon->[1] eq 'homonym'){
					
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					my $tt = "$taxon->[13] $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$taxon->[14]&id=$taxon->[0]"}, i($tax_name->[0]) . " $tax_name->[1]" );
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}	
					$taxa_tab .= li({-class=>'exploli'}, $tt );
				}
				elsif ( $taxon->[1] eq 'nomen nudum'){
					
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					my $tt = i($taxon->[13]); 
					if ($tax_name->[1]) {
						$tt .= " $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$taxon->[14]&id=$taxon->[0]"}, i($tax_name->[0]) . " $tax_name->[1]" );
					}
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}	
					$taxa_tab .= li({-class=>'exploli'}, $tt );
				}
				elsif ( $taxon->[1] eq 'status revivisco' or $taxon->[1] eq 'combinatio revivisco'){
					
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					my $tt = i($taxon->[13]); 
					if ($tax_name->[1]) {
						$tt .= " $trans->{'toen'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$taxon->[14]&id=$taxon->[0]"}, i($tax_name->[0]) . " $tax_name->[1]" );
					}
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}	
					$taxa_tab .= li({-class=>'exploli'}, $tt );
				}
				elsif ( $taxon->[1] eq 'nomen praeoccupatum'){
					
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					my $tt = i($taxon->[13]) . " $trans->{'fromto'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$taxon->[14]&id=$taxon->[0]"}, i($tax_name->[0]) . " $tax_name->[1]" ) . ' ' . i($trans->{'nnov'}->{$lang});
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= ", $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}	
					$taxa_tab .= li({-class=>'exploli'}, $tt );
				}
				elsif ( $taxon->[1] eq 'nomen oblitum'){
					
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					my $tt = i($taxon->[13]) . ", $trans->{'synonym'}->{$lang} $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$taxon->[14]&id=$taxon->[0]"}, i($tax_name->[0]) . " $tax_name->[1]" ) . ' ' . i($trans->{'nprotect'}->{$lang});
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= ", $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}	
					$taxa_tab .= li({-class=>'exploli'}, $tt );
				}
				elsif ( $taxon->[1] eq 'outside taxon'){
					
					my $tt = $taxon->[13];
					$taxa_tab .= li({-class=>'exploli'}, $tt );
				}
				elsif ( $taxon->[1] eq 'dead end'){
					
					my $tt = $taxon->[13];
					if ($tax_name->[1]) {
						$tt .= " $trans->{'relatedto'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$taxon->[14]&id=$taxon->[0]"}, i($tax_name->[0]) . " $tax_name->[1]" );
					}
					$taxa_tab .= li({-class=>'exploli'}, $tt );
				}
				else {
					my $tt = "$trans->{'other_name'}->{$lang} $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$taxon->[14]&id=$taxon->[0]"}, i($tax_name->[0]) . " $tax_name->[1]" );
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= " $trans->{'segun'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}	
					$taxa_tab .= li({-class=>'exploli'}, $tt );
				}
			}
			
			my $chr;
			if (scalar @chresos) {
				$chr = h4({-class=>'exploh4'}, $trans->{'Chresonym(s)'}->{$lang});
				$chr .= start_ul({-class=>'exploul'});
				foreach (@chresos) {
					$chr .= li({-class=>'exploli'}, $_);
				}
				$chr .= end_ul();
			}
	
			my ($cardtitle, $usage);
	
			$cardtitle = $trans->{'name'}->{$lang}; 
			$usage = h4({-class=>'exploh4'}, "$trans->{'statu(s)'}->{$lang}") . ul({-class=>'exploul'}, $taxa_tab);
			
			my $drvreq = "	SELECT index, orthographe, autorite, gen_type FROM noms_complets AS nc
					WHERE index in (SELECT index FROM noms WHERE ref_nom_parent = $name_id) ORDER BY orthographe;";
	
			my $derives = request_tab($drvreq,$dbc);
			
			my $drvnames;
			if (scalar @{$derives}) {
				$drvnames = h4({-class=>'exploh4'}, $trans->{'drvname(s)'}->{$lang});
				$drvnames .= start_ul({-class=>'exploul'});
				foreach ( @{$derives} ) {
					my $typestr;
					if ($_->[3]) { $typestr = span({-style=>'color: red'}, "&nbsp;  $trans->{'typespe'}->{$lang}") }
					$drvnames .= li({-class=>'exploli'},  a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$_->[0]"}, "$_->[1] $_->[2]") . $typestr);
				}
				$drvnames .= end_ul();
			}
	
			$fullhtml = 	div({-class=>'explocontent'},
						$up,
						div({-class=>'carddiv'},	
							h2({-class=>'exploh2'}, $cardtitle ),
							div({-class=>'subject'}, i($name->[0]) . " $name->[1]" ),
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
sub makeup {
	
	my ($cible, $display, $letter) = @_;
	
	if ($letter) { $letter = "&alph=$letter" }
	
 	my $up = a({-class=>'navlink', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$cible$letter"}, $display );

	return $up;
}

# Authors card
#################################################################
sub author_card {
	if ( my $dbc = db_connection($config) ) {
		my $author_id = $id;
		my $names = request_tab("SELECT nom, prenom FROM auteurs WHERE index = $author_id;",$dbc);
		my $ranks_ids = get_rank_ids( $dbc );

		#Get previous and next id
		my ( $previous_id, $prev_surname, $prev_name, $next_id, $next_surname, $next_name, $stop, $current_id, $current_surname, $current_name );
		$dbc->{RaiseError} = 1;
		
		my $sth2 = $dbc->prepare( "SELECT index, nom, prenom FROM auteurs
									ORDER BY nom, prenom;" );
		$sth2->execute( );
		$sth2->bind_columns( \( $current_id, $current_surname, $current_name ) );
		while ( $sth2->fetch() ){
			if ( $stop ){
				( $next_id, $next_surname, $next_name ) = ( $current_id, $current_surname, $current_name );
				last;
			}
			else {
				if ( $current_id == $author_id ){
					$stop = 1;
				}
				else {
					( $previous_id, $prev_surname, $prev_name ) = ( $current_id, $current_surname, $current_name );
				}
			}
		}
		$sth2->finish();

		my $up;
		if ($dbase ne 'cool' and $dbase ne 'flow' and $dbase ne 'flow2' and $dbase ne 'strepsiptera') {
		 	$up = 	div({-class=>'navup'}, $totop . ' > ' . makeup('authors', $trans->{'author(s)'}->{$lang}, lc(substr($current_surname, 0, 1))));
		}
		
		#my $up = prev_next_card( $card, $previous_id, "$prev_surname $prev_name", $next_id, "$next_surname $next_name" );

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
			#$sp_tab .= h3({-class=>'exploh3'}, $trans->{"spdescr"}->{$lang});
			my $subtitle;
			if ($size == 1 ) { $subtitle = $trans->{'taxon'}->{$lang}; }
			else { $subtitle = $trans->{'taxons'}->{$lang}; }
						
			$sp_tab .= start_ul({-class=>'exploul', -style=>'margin-top: 0px;'});
			foreach my $sp ( @{$sp_list} ){
				if ($current ne $sp->[6]) {
					unless ($current eq $sp_list->[0][6]) { $sp_tab .= br; }
					my $sbt = $trans->{$current."(s)"}->{$lang} || $curlang; 
					$sp_tab .= li({-class=>'exploli'}, "$count $sbt");
					$sp_tab .= $tmp_tab;

					$tmp_tab = '';
					$count = 0;
					$current = $sp->[6];
					$curlang = $sp->[5];	
				}
				$tmp_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$sp->[6]&id=$sp->[0]"}, i("$sp->[1]") . " $sp->[2]" ) );
				$count++;
			}
		        my $sbt = $trans->{$current."(s)"}->{$lang} || $curlang;
			if ($size != $count) { $sp_tab .= br; }
		        $sp_tab .= li({-class=>'exploli'}, "$count $sbt");        
			$sp_tab .= $tmp_tab;
			
			#if ($size != $count) {
				if ($dbase eq 'psylles') { $sp_tab .= "$size $subtitle" . $sp_tab; }
				else { $sp_tab = h4({-class=>'exploh4'}, "$size $subtitle") . $sp_tab; }
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
			#$pub_tab .= h3({-class=>'exploh3'}, $trans->{"publi(s)"}->{$lang});
			$pub_tab .= h4({-class=>'exploh4'}, "$size $trans->{'publi(s)'}->{$lang}");
			$pub_tab .= start_ul({-class=>'exploul'});
			foreach my $pub_id ( @{$pub_list} ){
				my $pub = pub_formating($pub_id->[0], $dbc );
				$pub_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$pub_id->[0]"}, "$pub" ) . getPDF($pub_id->[0]) );
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
			#$na_tab .= h3({-class=>'exploh3'}, $trans->{"nadescr"}->{$lang});
			$na_tab .= h4({-class=>'exploh4'}, "$size $trans->{'name(s)'}->{$lang}");
			$na_tab .= start_ul({-class=>'exploul'});
			foreach my $na ( @{$na_list} ){
				$na_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$na->[0]"}, i("$na->[1]") . " $na->[2]") . " $na->[3]" );
			}
			$na_tab .= end_ul() ;
		}
		
		$fullhtml = 	div({-class=>'explocontent'},
					$up,
					div({-class=>'carddiv'}, 
						h2({-class=>'exploh2'}, $trans->{'author'}->{$lang}),
						div({-class=>'subject'}, "$names->[0][0] $names->[0][1]"),
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
		
		my $princeps_list = '';


		my ( $previous_id, $prev_name, $prev_year, $next_id, $next_name, $next_year, $stop, $current_id, $current_name, $current_year );
		$dbc->{RaiseError} = 1;

		my $sth = $dbc->prepare( "SELECT p.index, a.nom, annee FROM publications AS p LEFT JOIN auteurs_x_publications AS axp ON p.index = axp.ref_publication
						LEFT JOIN auteurs AS a ON axp.ref_auteur = a.index WHERE axp.position = 1
						ORDER BY a.nom, annee;" );
		$sth->execute( );
		$sth->bind_columns( \( $current_id, $current_name, $current_year ) );
		while ( $sth->fetch() ){
			if ( $stop ){
				( $next_id, $next_name, $next_year ) = ( $current_id, $current_name, $current_year );
				last;
			}
			else {
				if ( $current_id == $pub_id ){
					$stop = 1;
				}
				else {
					( $previous_id, $prev_name, $prev_year ) = ( $current_id, $current_name, $current_year );
				}
			}
		}
		$sth->finish();

		my $up;
		if ($dbase ne 'cool' and $dbase ne 'flow' and $dbase ne 'flow2' and $dbase ne 'strepsiptera') {
		 	$up = 	div({-class=>'navup'}, $totop . ' > ' . makeup('publications', $trans->{'publications'}->{$lang}));
		}

		#my $up = prev_next_card( $card, $previous_id, "$prev_name $prev_year", $next_id, "$next_name $next_year" );
		
		my $req = "SELECT t.index, nc.index, nc.orthographe, nc.autorite, nc2.index, nc2.orthographe, nc2.autorite, s.en, s.$lang, r.ordre
				FROM taxons AS t JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
				LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
				LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				LEFT JOIN rangs AS r ON r.index = nc.ref_rang
				WHERE s.en != 'correct use' AND s.en != 'misidentification'
				AND s.en != 'description of the other sex'
				AND s.en != 'dead end'
				AND s.en != 'wrong spelling'
				AND nc.ref_publication_princeps = $pub_id
				ORDER BY nc.orthographe;";
		
		# Fetch names that were first published in this publication
		my $princeps = request_tab($req,$dbc);
		
		
		my $gorder = request_tab("SELECT ordre FROM rangs where en = 'genus';", $dbc);
		my $forder = request_tab("SELECT ordre FROM rangs where en = 'family';", $dbc);
		my $validcard;
		foreach my $name ( @{$princeps} ){
			if ($name->[9] > $gorder->[0][0]) { $validcard = 'species' } 
			elsif ($name->[9] > $forder->[0][0]) { $validcard = 'genus' } 
			elsif ($name->[9] == $forder->[0][0]) { $validcard = 'family' } 
			
			if ( $name->[7] eq 'valid' ){ 
				if ($name->[9] > $gorder->[0][0]) { 
					$princeps_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$validcard&id=$name->[0]"}, i($name->[2]) . " $name->[3]" ) );
				}
				else { $princeps_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$name->[1]"}, i($name->[2]) . " $name->[3]" ) ); }
			}
			else {
				$princeps_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$name->[1]"}, i($name->[2]) . " $name->[3]" ) . 
						  " $name->[8] $trans->{'of'}->{$lang} " .
						  a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$validcard&id=$name->[0]"}, i($name->[5]) . " $name->[6]" ) );
			}
			
#			if ( $name->[7] eq 'previous combination' ) {
#				$princeps_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$name->[1]"}, i($name->[2]) . " $name->[3]" ) . " $name->[8] $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$validcard&id=$name->[4]"}, i($name->[5]) . " $name->[6]" ) );
#			}
#			elsif ( $name->[7] eq 'synonym' ) {
#				$princeps_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$name->[1]"}, i($name->[2]) . " $name->[3]" ) ." $name->[8] $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$validcard&id=$name->[4]"}, i($name->[5]) . " $name->[6]" ) );
#			}
#			elsif ( $name->[7] eq 'wrong spelling' ) {
#				$princeps_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$name->[1]"}, i($name->[2]) . " $name->[3]" ) ." $name->[8] $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$validcard&id=$name->[4]"}, i($name->[5]) . " $name->[6]" ) );
#			}
#			elsif ( $name->[7] eq 'misidentification' ){
#				$princeps_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$name->[1]"}, i($name->[2]) . " $name->[3]" ) ." $name->[8] $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$validcard&id=$name->[4]"}, i($name->[5]) . " $name->[6]" ) );
#			}
#			elsif ($name->[7] eq 'incorrect original spelling' or $name->[6] eq 'incorrect subsequent spelling') {
#				$princeps_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$name->[1]"}, i($name->[2]) . " $name->[3]" ) ." $name->[8] $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$validcard&id=$name->[4]"}, i($name->[5]) . " $name->[6]" ) );
#			}
		}
		if ( $princeps_list ){
			$princeps_list = h4({-class=>'exploh4'}, "$trans->{'descr_prin'}->{$lang}") . ul({-class=>'exploul'}, $princeps_list );
		}

		# Fetch synonymy denonciation made in this publication
		my $syn_list = '';
		$sth = $dbc->prepare( "SELECT txn.ref_nom, txn.ref_taxon, txn.exactitude, txn.completude, txn.exactitude_male, txn.completude_male, txn.exactitude_femelle, txn.completude_femelle, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, ordre
					FROM taxons_x_noms AS txn LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
					LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
					LEFT JOIN rangs AS r ON r.index = nc2.ref_rang
					WHERE txn.ref_publication_denonciation = $pub_id 
					AND s.en = 'synonym' 
					ORDER BY nc.orthographe;" );
		$sth->execute;
		my ( $ref_nom, $ref_taxon, $exactitude, $completude, $exactitude_male, $completude_male, $exactitude_femelle, $completude_femelle, $orthographe, $autorite, $tax_name, $tax_autorite, $ordre );
		$sth->bind_columns( \( $ref_nom, $ref_taxon, $exactitude, $completude, $exactitude_male, $completude_male, $exactitude_femelle, $completude_femelle, $orthographe, $autorite, $tax_name, $tax_autorite, $ordre ) );
		
		while ( $sth->fetch ) {

			if ($ordre > $gorder->[0][0]) { $validcard = 'species' } 
			elsif ($ordre > $forder->[0][0]) { $validcard = 'genus' } 
			elsif ($ordre == $forder->[0][0]) { $validcard = 'family' }

			my $ambiguous = synonymy( $exactitude, $exactitude_male, $exactitude_femelle );
			my $complete = completeness( $completude, $completude_male, $completude_femelle );
			$syn_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) ." $trans->{'synonym'}->{$lang} $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$validcard&id=$ref_taxon"}, i($tax_name) . " $tax_autorite" ) );
		}
		$sth->finish(); # finalize the request
		if ( $syn_list ){
			$syn_list = h4({-class=>'exploh4'}, "$trans->{'descr_syn'}->{$lang}") . ul({-class=>'exploul'}, $syn_list);
		}

		# Fetch misidentifications  made in this publication
		my $error_list = '';
		$sth = $dbc->prepare( "SELECT txn.ref_nom, txn.ref_taxon, txn.exactitude, txn.completude, txn.exactitude_male, txn.completude_male, txn.exactitude_femelle, txn.completude_femelle, txn.ref_publication_utilisant, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, ordre
					FROM taxons_x_noms AS txn LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
					LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
					LEFT JOIN rangs AS r ON r.index = nc2.ref_rang
					WHERE txn.ref_publication_denonciation = $pub_id 
					AND s.en = 'Error of identification' 
					ORDER BY nc.orthographe;" );
		$sth->execute;
		my ( $ref_publication_utilisant );
		( $ref_nom, $ref_taxon, $exactitude, $completude, $exactitude_male, $completude_male, $exactitude_femelle, $completude_femelle, $orthographe, $autorite, $tax_name, $tax_autorite, $ordre ) = ( '', '', '', '', '', '', '', '', '', '', '', '', '' );
		$sth->bind_columns( \( $ref_nom, $ref_taxon, $exactitude, $completude, $exactitude_male, $completude_male, $exactitude_femelle, $completude_femelle, $ref_publication_utilisant, $orthographe, $autorite, $tax_name, $tax_autorite, $ordre ) );
		while ( $sth->fetch ) {
			
			if ($ordre > $gorder->[0][0]) { $validcard = 'species' } 
			elsif ($ordre > $forder->[0][0]) { $validcard = 'genus' } 
			elsif ($ordre == $forder->[0][0]) { $validcard = 'family' }
			
			my $ambiguous = synonymy( $exactitude, $exactitude_male, $exactitude_femelle );
			my $complete = completeness( $completude, $completude_male, $completude_femelle );
			my @pub_use = publication($ref_publication_utilisant, 0, 1, $dbc );
			$error_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) .
					" $trans->{'id_error'}->{$lang} $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$validcard&id=$ref_taxon"}, i($tax_name) . 
					" $tax_autorite" ) . i( " in " ) . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$ref_publication_utilisant"}, "$pub_use[1]" ) . 
					getPDF($ref_publication_utilisant) );
		}
		$sth->finish(); 
		
		if ( $error_list ){
			$error_list = h4({-class=>'exploh4'}, "$trans->{'descr_err'}->{$lang}") . ul({-class=>'exploul'}, $error_list);
		}
		
		# Fetch transfer made in this publication
		my $transfer_list = '';
		my $req = "SELECT txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, ordre
				FROM taxons_x_noms AS txn LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
				LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
				LEFT JOIN rangs AS r ON r.index = nc2.ref_rang
				WHERE txn.ref_publication_denonciation = $pub_id 
				AND s.en = 'previous combination' 
				ORDER BY nc.orthographe;";
		$sth = $dbc->prepare($req) or die $req;
		$sth->execute or die $req;

		( $ref_nom, $ref_taxon, $orthographe, $autorite, $tax_name, $tax_autorite, $ordre ) = ( '', '', '', '', '', '', '');
		$sth->bind_columns( \( $ref_nom, $ref_taxon, $orthographe, $autorite, $tax_name, $tax_autorite, $ordre ) ) or die 1;
		
		while ( $sth->fetch ) {
			
			if ($ordre > $gorder->[0][0]) { $validcard = 'species' } 
			elsif ($ordre > $forder->[0][0]) { $validcard = 'genus' } 
			elsif ($ordre == $forder->[0][0]) { $validcard = 'family' }
			
			$transfer_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$validcard&id=$ref_taxon"}, i($tax_name) . " $tax_autorite" ) . " $trans->{'new_comb'}->{$lang} $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) );
		}
		$sth->finish();
		
		if ( $transfer_list ){
			$transfer_list = h4({-class=>'exploh4'}, "$trans->{'transfer(s)'}->{$lang}") . ul({-class=>'exploul'}, $transfer_list);
		}
		
		# Fetch emendeds made in this publication
		my $emend_list = '';
		$req = "SELECT txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, ordre
									FROM taxons_x_noms AS txn LEFT JOIN statuts AS s ON txn.ref_statut = s.index
									LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
									LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
									LEFT JOIN rangs AS r ON r.index = nc2.ref_rang
									WHERE txn.ref_publication_denonciation = $pub_id 
									AND s.en = 'incorrect original spelling'
									GROUP BY txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, ordre
									ORDER BY nc.orthographe;";
		$sth = $dbc->prepare($req) or die $req;
		$sth->execute or die $req;

		( $ref_nom, $ref_taxon, $orthographe, $autorite, $tax_name, $tax_autorite, $ordre ) = ( '', '', '', '', '', '', '');
		$sth->bind_columns( \( $ref_nom, $ref_taxon, $orthographe, $autorite, $tax_name, $tax_autorite, $ordre ) ) or die 1;
		
		while ( $sth->fetch ) {
			
			if ($ordre > $gorder->[0][0]) { $validcard = 'species' } 
			elsif ($ordre > $forder->[0][0]) { $validcard = 'genus' } 
			elsif ($ordre == $forder->[0][0]) { $validcard = 'family' }
			
			$emend_list .= li({-class=>'exploli'}, 
						a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) .
						" $trans->{'emended'}->{$lang} $trans->{'toen'}->{$lang} " . 
						a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$validcard&id=$ref_taxon"}, i($tax_name) . " $tax_autorite" ) 
					);
		}
		$sth->finish();

		if ( $emend_list ){
			$emend_list = h4({-class=>'exploh4'}, "$trans->{'emendation(s)'}->{$lang}") . ul({-class=>'exploul'}, $emend_list);
		}


		# Fetch wrong spelling made in this publication
		my $wsp_list = '';
		my $corwsp_list = '';
		$req = "SELECT txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, ordre, s.$lang, txn.ref_publication_denonciation
				FROM taxons_x_noms AS txn 
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
				LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
				LEFT JOIN rangs AS r ON r.index = nc2.ref_rang
				WHERE s.en = 'wrong spelling'
				AND (txn.ref_publication_denonciation = $pub_id OR txn.ref_publication_utilisant = $pub_id)
				group by txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, ordre, s.$lang, txn.ref_publication_denonciation
				ORDER BY nc.orthographe;";
		$sth = $dbc->prepare($req) or die $req;
		$sth->execute or die $req;

		my $statut;
		my $pubden;
		( $ref_nom, $ref_taxon, $orthographe, $autorite, $tax_name, $tax_autorite, $ordre, $statut, $pubden ) = ( '', '', '', '', '', '', '');
		$sth->bind_columns( \( $ref_nom, $ref_taxon, $orthographe, $autorite, $tax_name, $tax_autorite, $ordre, $statut, $pubden ) ) or die 1;
		
		while ( $sth->fetch ) {
			
			if ($ordre > $gorder->[0][0]) { $validcard = 'species' } 
			elsif ($ordre > $forder->[0][0]) { $validcard = 'genus' } 
			elsif ($ordre == $forder->[0][0]) { $validcard = 'family' }
			
			if ($pubden == $pub_id) {
				$corwsp_list.= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) . " $statut $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$validcard&id=$ref_taxon"}, i($tax_name) . " $tax_autorite" ) );
			}
			else {
				$wsp_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) . " $statut $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$validcard&id=$ref_taxon"}, i($tax_name) . " $tax_autorite" ) );
			}
		}
		$sth->finish();
		
		if ( $wsp_list ){
			$wsp_list = h4({-class=>'exploh4'}, ucfirst($statut)) . ul({-class=>'exploul'}, $wsp_list);
		}
		if ( $corwsp_list ){
			$corwsp_list = h4({-class=>'exploh4'}, ucfirst($trans->{'wrong_spelling_correction'}->{$lang})) . ul({-class=>'exploul'}, $corwsp_list);
		}
		
		# Fetch Chresonyms in this publication
		my $chre_list = '';
		$req = "SELECT txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, ordre, s.$lang
				FROM taxons_x_noms AS txn 
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
				LEFT JOIN taxons_x_noms AS txn2 ON txn.ref_taxon = txn2.ref_taxon
				LEFT JOIN noms_complets AS nc2 ON txn2.ref_nom_cible = nc2.index
				LEFT JOIN statuts AS s2 ON txn2.ref_statut = s2.index
				LEFT JOIN rangs AS r ON r.index = nc2.ref_rang
				WHERE txn.ref_publication_utilisant = $pub_id
				AND s.en = 'correct use'
				AND s2.en = 'valid'
				ORDER BY nc.orthographe;";
		$sth = $dbc->prepare($req) or die $req;
		$sth->execute or die $req;

		my $statut;
		( $ref_nom, $ref_taxon, $orthographe, $autorite, $tax_name, $tax_autorite, $ordre, $statut ) = ( '', '', '', '', '', '', '', '');
		$sth->bind_columns( \( $ref_nom, $ref_taxon, $orthographe, $autorite, $tax_name, $tax_autorite, $ordre, $statut ) ) or die 1;
		
		while ( $sth->fetch ) {
			
			if ($ordre > $gorder->[0][0]) { $validcard = 'species' } 
			elsif ($ordre > $forder->[0][0]) { $validcard = 'genus' } 
			elsif ($ordre == $forder->[0][0]) { $validcard = 'family' }
			
			$chre_list.= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) );
		}
		$sth->finish();
		
		if ( $chre_list ){
			$chre_list = h4({-class=>'exploh4'}, ucfirst($statut)) . ul({-class=>'exploul'}, $chre_list);
		}		

		# Fetch distribution documented in this publication
		my $dist_list = '';
		$req = "SELECT txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, ordre
				FROM taxons_x_noms AS txn 
				LEFT JOIN taxons_x_pays AS txp ON txp.ref_taxon = txn.ref_taxon
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
				LEFT JOIN rangs AS r ON r.index = nc.ref_rang
				WHERE txp.ref_publication_ori = $pub_id
				AND s.en = 'valid'
				group by txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, ordre
				ORDER BY nc.orthographe;";
		$sth = $dbc->prepare($req) or die $req;
		$sth->execute or die $req;

		my $statut;
		( $ref_nom, $ref_taxon, $orthographe, $autorite, $ordre ) = ( '', '', '', '', '');
		$sth->bind_columns( \( $ref_nom, $ref_taxon, $orthographe, $autorite, $ordre ) ) or die 1;
		
		while ( $sth->fetch ) {
			
			if ($ordre > $gorder->[0][0]) { $validcard = 'species' } 
			elsif ($ordre > $forder->[0][0]) { $validcard = 'genus' } 
			elsif ($ordre == $forder->[0][0]) { $validcard = 'family' }
			
			$dist_list.= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) );
		}
		$sth->finish();
		
		if ( $dist_list ){
			$dist_list = h4({-class=>'exploh4'}, ucfirst($trans->{'countries'}->{$lang})) . ul({-class=>'exploul'}, $dist_list);
		}		
		
		# Fetch host plants documented in this publication
		my $hp_list = '';
		$req = "SELECT txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, ordre
				FROM taxons_x_noms AS txn 
				LEFT JOIN taxons_x_plantes AS txp ON txp.ref_taxon = txn.ref_taxon
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
				LEFT JOIN rangs AS r ON r.index = nc.ref_rang
				WHERE txp.ref_publication_ori = $pub_id
				AND s.en = 'valid'
				group by txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, ordre
				ORDER BY nc.orthographe;";
		$sth = $dbc->prepare($req) or die $req;
		$sth->execute or die $req;

		my $statut;
		( $ref_nom, $ref_taxon, $orthographe, $autorite, $ordre ) = ( '', '', '', '', '');
		$sth->bind_columns( \( $ref_nom, $ref_taxon, $orthographe, $autorite, $ordre ) ) or die 1;
		
		while ( $sth->fetch ) {
			
			if ($ordre > $gorder->[0][0]) { $validcard = 'species' } 
			elsif ($ordre > $forder->[0][0]) { $validcard = 'genus' } 
			elsif ($ordre == $forder->[0][0]) { $validcard = 'family' }
			
			$hp_list.= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) );
		}
		$sth->finish();
		
		if ( $hp_list ){
			$hp_list = h4({-class=>'exploh4'}, ucfirst($trans->{'hostplant(s)'}->{$lang})) . ul({-class=>'exploul'}, $hp_list);
		}		
		
		my $pub = pub_formating($pub_id, $dbc) . getPDF($pub_id);
		
		$fullhtml = 	div({-class=>'explocontent'},
					$up,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{'publication'}->{$lang} ),
						a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$pub_id"},
							span({-class=>'subject', -id=>'pubtitle'}, $pub ),
						),
						$princeps_list,
						$syn_list,
						$transfer_list,
						$error_list,
						$emend_list,
						$wsp_list,
						$corwsp_list,
						$chre_list,
						$dist_list,
						$hp_list
					)
				);
				
		print $fullhtml;
			
		$dbc->disconnect;
	}
	else {}
}

# Plant card
#################################################################
sub plant_card {
	if ( my $dbc = db_connection($config) ) {
		my $plant_id = $id;
		
		my $plant = request_row("SELECT p1.nom, p2.nom, p3.nom, p1.autorite, p2.index, p3.index, r.en FROM plantes AS p1 
						LEFT JOIN plantes AS p2 ON (p1.ref_parent = p2.index)
						LEFT JOIN plantes AS p3 ON (p2.ref_parent = p3.index)
						LEFT JOIN rangs AS r ON (p1.ref_rang = r.index)
						WHERE p1.index = $plant_id;",$dbc);
		
		if ($plant->[6] eq 'genus') {
			my $sons_list = request_tab("SELECT p1.nom, p2.nom, p3.nom, p1.autorite FROM plantes AS p1 
						LEFT JOIN plantes AS p2 ON (p1.ref_parent = p2.index)
						LEFT JOIN plantes AS p3 ON (p2.ref_parent = p3.index)
						WHERE p1.index = $plant_id;",$dbc);
		}
		
		#Get previous and next id
		my ( $previous_id, $prev_name, $next_id, $next_name, $stop, $current_id, $current_name, $current_fam, $current_gen, $current_spe, $current_authority );
		$dbc->{RaiseError} = 1;

		my $sth2 = $dbc->prepare( "SELECT p1.index, p1.nom, p2.nom, p3.nom, p1.autorite FROM plantes AS p1 
						LEFT JOIN plantes AS p2 ON (p1.ref_parent = p2.index)
						LEFT JOIN plantes AS p3 ON (p2.ref_parent = p3.index)
						WHERE p1.ref_rang in (SELECT index FROM rangs WHERE en in ('genus','species'))
						AND p1.index in (SELECT distinct ref_plante FROM taxons_x_plantes)
						ORDER BY p2.nom, p1.nom, p3.nom;" );
		$sth2->execute( );
		$sth2->bind_columns( \( $current_id, $current_spe, $current_gen, $current_fam, $current_authority ) );
		while ( $sth2->fetch() ){
			if ($current_fam) { $current_name = i("$current_gen $current_spe")." $current_authority  ($current_fam)";}
			else { $current_name = i("$current_spe")." $current_authority ($current_gen)";}
			if ( $stop ){
				( $next_id, $next_name ) = ( $current_id, $current_name );
				last;
			}
			else {
				if ( $current_id == $plant_id ){
					$stop = 1;
				}
				else {
					( $previous_id, $prev_name ) = ( $current_id, $current_name );
				}
			}
		}
		$sth2->finish();

		my $sp_list = request_tab("SELECT distinct t.index, n.orthographe, n.autorite, t.ref_taxon_parent, r.en, LOWER ( n.orthographe )
				FROM taxons AS t 
				LEFT JOIN taxons_x_plantes AS txp ON t.index = txp.ref_taxon
				LEFT JOIN plantes AS p ON p.index = txp.ref_plante
				LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
				LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
				LEFT JOIN rangs AS r ON t.ref_rang = r.index
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				WHERE r.en = 'species' AND s.en = 'valid' AND (txp.ref_plante = $plant_id OR p.ref_valide = $plant_id )
				ORDER BY LOWER ( n.orthographe );",$dbc);

		my $sp_tab;
		if ( scalar @{$sp_list} != 0){
			my $size = scalar @{$sp_list};
			$sp_tab = h4({-class=>'exploh4'}, "$trans->{'hpof'}->{$lang} $size $trans->{'species(s)'}->{$lang}");
			$sp_tab .= start_ul({-class=>'exploul'});
			foreach my $sp ( @{$sp_list} ){
				my $parent_name = [];
				$parent_name = request_row( "SELECT parent_taxon_name($sp->[3],'family');", $dbc );
				
				$sp_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$sp->[4]&id=$sp->[0]"}, i("$sp->[1]"), " $sp->[2] &nbsp;($parent_name->[0])"));
			}
			$sp_tab .= end_ul();
		}

		my $pdisp;	
		if ($plant->[2]) { 	
			$pdisp = i("$plant->[1] $plant->[0]") . " $plant->[3]"; 
			$plant->[2] = " ($plant->[2])";
		}
		elsif ($plant->[1])  { 	
			$pdisp = i("$plant->[0]")." $plant->[3]";
			$plant->[2] = " ($plant->[1])";
		}
		else {
			$pdisp = "$plant->[0]";
		}

		$fullhtml = div({-class=>'explocontent'},
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{'plant'}->{$lang}),
						div({-class=>'subject'}, $pdisp." $plant->[2]"),
						$sp_tab
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
		
		my $taxon = request_row("SELECT ta.index, (get_taxon_associe(ta.index)).*
						FROM taxons_associes AS ta 
						WHERE ta.index = $taxon_id;",$dbc);
				

		my $sp_list = request_tab("SELECT distinct t.index, n.orthographe, n.autorite, t.ref_taxon_parent, r.en, LOWER ( n.orthographe )
				FROM taxons AS t
				LEFT JOIN taxons_x_taxons_associes AS txt ON t.index = txt.ref_taxon
				LEFT JOIN types_association AS ty ON ty.index = txt.ref_type_association
				LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
				LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
				LEFT JOIN rangs AS r ON t.ref_rang = r.index
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				WHERE r.en = 'species' AND s.en = 'valid' 
				AND txt.ref_taxon_associe = $taxon_id
				AND ty.en = '$type'
				ORDER BY LOWER ( n.orthographe );",$dbc);

		my $tab;
		if ( scalar @{$sp_list} != 0){
			my $size = scalar @{$sp_list};
			$tab = h4({-class=>'exploh4'}, ucfirst($trans->{$type}->{$lang})." $trans->{'of'}->{$lang} $size $trans->{'species(s)'}->{$lang}");
			$tab .= start_ul({-class=>'exploul'});
			foreach my $sp ( @{$sp_list} ){
				my $parent_name = [];
				$parent_name = request_row( "SELECT parent_taxon_name($sp->[3],'family');", $dbc );
				
				$tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$sp->[4]&id=$sp->[0]"}, i("$sp->[1]"), " $sp->[2]") . "&nbsp; ($parent_name->[0])" );
			}
			$tab .= end_ul();
		}

		my $associate = i($taxon->[1]);
		if ($taxon->[2]) { $associate .= " $taxon->[2]" }
		my $higher;
		if ($taxon->[3]) { $higher .= "&nbsp; $taxon->[3]" }
		if ($taxon->[4]) { $higher .= " ($taxon->[4])" }

		$fullhtml = div({-class=>'explocontent'},
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, ucfirst($trans->{$type}->{$lang})),
						span({-class=>'subject'}, $associate). $higher,
						$tab
					)
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
				
		my ($country, $countrySQL);
		
		$country = request_row("SELECT $lang FROM pays WHERE index = $country_id;",$dbc);
		
		$country = $countrySQL = $country->[0];
		$countrySQL =~ s/\'/\\\'/;
				
		my $regions = request_tab("SELECT index FROM pays WHERE $lang like '$countrySQL %' order by $lang;",$dbc,1);
		
#		my ( $previous_id, $prev_name, $next_id, $next_name, $stop, $current_id, $current_name );
		$dbc->{RaiseError} = 1;

#		my $sth2 = $dbc->prepare( "SELECT index, $lang FROM pays WHERE index in (SELECT distinct ref_pays FROM taxons_x_pays) ORDER BY $lang;" );
#		$sth2->execute( );
#		$sth2->bind_columns( \( $current_id, $current_name ) );
#		while ( $sth2->fetch() ){
#			if ( $stop ){
#				( $next_id, $next_name ) = ( $current_id, $current_name );
#				last;
#			}
#			else {
#				if ( $current_id == $country_id ){
#					$stop = 1;
#				}
#				else {
#					( $previous_id, $prev_name ) = ( $current_id, $current_name );
#				}
#			}
#		}
#		$sth2->finish();

		my $up;
		if ($dbase eq 'cipa') { 
		 	$up = 	div({-class=>'navup'}, $totop . ' > ' . makeup('countries', $trans->{'countries'}->{$lang}, lc(substr($country, 0, 1))));
		}
		elsif ($dbase ne 'cool' and $dbase ne 'flow' and $dbase ne 'flow2' and $dbase ne 'strepsiptera') {
		 	$up = 	div({-class=>'navup'}, $totop . ' > ' . makeup('countries', $trans->{'countries'}->{$lang}, lc(substr($country, 0, 1))));
		}

		#my $up = prev_next_card( $card, $previous_id, $prev_name, $next_id, $next_name );

		my ($taxname, $taxauthor, $croise, $precise, $getall);
		
		if ($taxnameid) { 
			($taxname, $taxauthor) = @{request_row("SELECT orthographe, autorite FROM noms_complets WHERE index = $taxnameid;",$dbc)};
			$croise = "AND n.orthographe like '$taxname %'";
			$precise = "$trans->{'dansin'}->{$lang} $taxname $taxauthor";
			$getall = span('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;', a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=$country_id"}, $trans->{'getAllSpeciesFrom'}->{$lang}));
		}
		
		# Fetch species present in the country
		my $sp_list = request_tab("SELECT DISTINCT txp.ref_taxon, n.orthographe, n.autorite, r.en, LOWER ( n.orthographe )
						FROM taxons_x_pays AS txp 
						LEFT JOIN taxons_x_noms AS txn ON txp.ref_taxon = txn.ref_taxon
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
						LEFT JOIN rangs AS r ON r.index = n.ref_rang
						WHERE ref_pays = $country_id AND s.fr = 'valide'
						$croise
						group by txp.ref_taxon, n.orthographe, n.autorite, r.en
						ORDER BY LOWER ( n.orthographe );",$dbc);
		
		my $sp_tab;
		if ( scalar @{$sp_list} != 0){
			my $size = scalar @{$sp_list};
			h3({-class=>'exploh3'}, $trans->{"SP_CO"}->{$lang}),
			$sp_tab = h4({-class=>'exploh4'}, "$size $trans->{'species(s)'}->{$lang}  $precise");
			$sp_tab .= start_ul({-class=>'exploul'});
			foreach my $sp ( @{$sp_list} ){
				$sp_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$sp->[3]&id=$sp->[0]"}, i("$sp->[1]") . " $sp->[2]" ) );
			}
			$sp_tab .= end_ul();
		}
		else {
			#$sp_tab = ul({-class=>'exploul'}, li({-class=>'exploli'}, $trans->{"UNK"}->{$lang}));
		}
		
		foreach (@{$regions}) {
			my $sp_list = request_tab("SELECT DISTINCT txp.ref_taxon, n.orthographe, n.autorite, r.en, p.$lang, LOWER ( n.orthographe )
							FROM taxons_x_pays AS txp LEFT JOIN taxons_x_noms AS txn ON txp.ref_taxon = txn.ref_taxon
							LEFT JOIN statuts AS s ON txn.ref_statut = s.index
							LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
							LEFT JOIN rangs AS r ON r.index = n.ref_rang
							LEFT JOIN pays AS p ON p.index = txp.ref_pays
							WHERE ref_pays = $_ AND s.fr = 'valide'
							$croise
							ORDER BY LOWER ( n.orthographe );",$dbc);
			
			if ( scalar @{$sp_list} != 0){
				my $size = scalar @{$sp_list};
				$sp_tab .= h4({-class=>'exploh4'}, $sp_list->[0][4]);
				$sp_tab .= h4({-class=>'exploh4'}, "$size $trans->{'species(s)'}->{$lang} $precise");
				$sp_tab .= start_ul({-class=>'exploul'});
				foreach my $sp ( @{$sp_list} ){
					$sp_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$sp->[3]&id=$sp->[0]"}, i("$sp->[1]") . " $sp->[2]" ) );
				}
				$sp_tab .= end_ul();
			}
		}
		
		# Fetch repositories present in the country
		my $de_list = request_tab("SELECT l.index, l.nom, $lang FROM lieux_depot AS l LEFT JOIN pays as p ON (l.ref_pays = p.index)
									WHERE p.index = $country_id
									ORDER BY l.nom;",$dbc); # Fetch repositories list from DB

		my $de_tab;
		if ( scalar @{$de_list} != 0){
			my $size = scalar @{$de_list};
			$de_tab = h3({-class=>'exploh3'}, $trans->{"DE_CO"}->{$lang});
			$de_tab .= h4({-class=>'exploh4'}, "$size $trans->{'repos(s)'}->{$lang}");
			$de_tab .= start_ul({-class=>'exploul'});
			foreach my $repository ( @{$de_list} ){
				$de_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=repository&id=$repository->[0]"}, "$repository->[1], $repository->[2]" ) );
			}
			$de_tab .= end_ul();
		}
		else {
			#$de_tab = ul({-class=>'exploul'}, li({-class=>'exploli'}, $trans->{"none"}->{$lang}));
		}	
		
		my $vdisplay = get_vernaculars($dbc, 'nv.ref_pays', $country_id);
		
		$fullhtml = 	div({-class=>'explocontent'},
					$up,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{'country'}->{$lang}),
						div({-class=>'subject'}, $country), $getall,
						$sp_tab,
						$de_tab, br,
						$vdisplay
						
					)
				);
				
		print $fullhtml;

		$dbc->disconnect;
	}
	else {}
}

sub image_card {
	
	if ( my $dbc = db_connection($config) ) {
		
		if ($search eq 'taxon') {
			my $req = "	SELECT I.url, txi.commentaire, nc.orthographe, nc.autorite, txi.ref_taxon
					FROM images AS I 
					LEFT JOIN taxons_x_images AS txi ON I.index = txi.ref_image
					LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = txi.ref_taxon
					LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
					LEFT JOIN statuts AS s ON s.index = txn.ref_statut
					WHERE I.index = $id
					AND s.en = 'valid';";
			
			my $image = request_row($req,$dbc);
			
			$req = "	SELECT I.index, I.icone_url
					FROM images AS I 
					LEFT JOIN taxons_x_images AS txi ON I.index = txi.ref_image
					WHERE I.index != $id
					AND txi.ref_taxon = $image->[4];";
			
			my $mini = request_tab($req,$dbc);
			
			my $icons;
			foreach my $icon ( @{$mini} ) {
				$icons .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=image&id=$icon->[0]&search=taxon"}, img({-src=>"$icon->[1]", -style=>'border: 0; margin: 0;'})));
			}
			if ($icons) { $icons = br . br . $icons . div({-style=>'clear: both;'}); }
			
			my $up;
			if ($dbase ne 'cool' and $dbase ne 'flow' and $dbase ne 'flow2' and $dbase ne 'strepsiptera') {
				$up = 	div({-class=>'navup'}, $totop );
				$up .=  div({-class=>'tolist'}, '&nbsp;');
				#$up .=  div({-class=>'hierarchy'}, a({-class=>'navlink', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$image->[4]"}, i($image->[2]) . " $image->[3]" ));
				#$up .=  div({-class=>'hierarchy'}, a({-class=>'navlink', -href=>"javascript: history.go(-1)"}, i($image->[2]) . " $image->[3]" ));
			}
			
			my $comment;
			if ($image->[1]) { $comment = $image->[1] . br . br; }
	
			$fullhtml = 	div({-class=>'explocontent'},
						$up,
						div({-class=>'carddiv'},
							h2({-class=>'exploh2'}, ucfirst($trans->{'image'}->{$lang})),
							a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$image->[4]"}, i($image->[2]) . " $image->[3]" ), br, br,
							$comment,
							img({-src=>"$image->[0]", -style=>'border: 0; margin: 0;'}),
							$icons
						)
					);
		}
		elsif ($search eq 'nom') {
			my $req = "	SELECT I.url, nxi.commentaire, nc.orthographe, nc.autorite, txn.ref_taxon, nxi.ref_nom
					FROM images AS I 
					LEFT JOIN noms_x_images AS nxi ON I.index = nxi.ref_image
					LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = nxi.ref_nom
					LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
					WHERE I.index = $id;";
			
			my $image = request_row($req,$dbc);
			
			$req = "SELECT I.index, I.icone_url
					FROM images AS I 
					LEFT JOIN noms_x_images AS nxi ON I.index = nxi.ref_image
					WHERE I.index != $id
					AND nxi.ref_nom = $image->[5];";
			
			my $mini = request_tab($req,$dbc);
			
			my $icons;
			foreach my $icon ( @{$mini} ) {
				$icons .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=image&id=$icon->[0]&search=nom"}, img({-src=>"$icon->[1]", -style=>'border: 0; margin: 0;'})));
			}
			if ($icons) { $icons = br . br . $icons . div({-style=>'clear: both;'}); }
			
			my $up;
			if ($dbase ne 'cool' and $dbase ne 'flow' and $dbase ne 'flow2' and $dbase ne 'strepsiptera') {
				$up = 	div({-class=>'navup'}, $totop );
				$up .=  div({-class=>'tolist'}, '&nbsp;');
				#$up .=  div({-class=>'hierarchy'}, a({-class=>'navlink', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$image->[4]"}, i($image->[2]) . " $image->[3]" ));
				#$up .=  div({-class=>'hierarchy'}, a({-class=>'navlink', -href=>"javascript: history.go(-1)"}, i($image->[2]) . " $image->[3]" ));
			}
			
			my $comment;
			if ($image->[1]) { $comment = $image->[1] . br . br; }
	
			$fullhtml = 	div({-class=>'explocontent'},
						$up,
						div({-class=>'carddiv'},
							h2({-class=>'exploh2'}, ucfirst($trans->{'image'}->{$lang})),
							a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$image->[4]"}, i($image->[2]) . " $image->[3]" ), br, br,
							$comment,
							img({-src=>"$image->[0]", -style=>"border: 0; margin: 0;", -class=>'imgcard'}),
							$icons
						)
					);
		}
		print $fullhtml;
		$dbc->disconnect;
	}
}

sub vernacular_card {
	
	if ( my $dbc = db_connection($config) ) {
		
		my $req = "SELECT v.nom, l.langage, p.en, txn.ref_taxon, nc.orthographe, nc.autorite, r.en, txv.ref_pub, v.ref_pays
			FROM noms_vernaculaires AS v
			LEFT JOIN taxons_x_vernaculaires AS txv ON v.index = txv.ref_nom
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

		my $up;
		if ($dbase ne 'cool' and $dbase ne 'flow' and $dbase ne 'flow2' and $dbase ne 'strepsiptera') {
		 	$up = 	div({-class=>'navup'}, $totop );
			$up .=  div({-class=>'tolist'}, makeup('vernaculars', $trans->{'vernaculars'}->{$lang}));
		}
		
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
					$taxas{$_->[3]}{'label'} = a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$_->[6]&id=$_->[3]"}, "$_->[4] $_->[5]" );
					
					$taxas{$_->[3]}{'refs'} = ();
				}
				
				if (scalar @pub) {
					push(@{$taxas{$_->[3]}{'refs'}}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$_->[7]"}, "$pub[1]" ) . getPDF($_->[7]));
				}
			}
					
			foreach (@order) {
				my $list = $taxas{$_}{'label'};
				if ($taxas{$_}{'refs'}) { $list .= ' according to ' . join (', ', @{$taxas{$_}{'refs'}}); }
				$vdisplay .= li({-class=>'exploli'}, $list);
			}
			
			$vdisplay = ul({-class=>'exploul'}, $vdisplay) . p;
		}
		
		my $xpays;
		if ($pays) { $xpays = " in " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=".$ref_pays}, $pays); }
		
		my $fullhtml = 	div({-class=>'explocontent'},
					$up,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{'vernacular'}->{$lang}), p,
						div({-class=>'subject', -style=>'display: inline;'}, $nom) . $xpays . " ($langg)", p,
						h4({-style=>'font-size: 17px;', -class=>'exploh4'}, $trans->{'sciname(s)'}->{$lang}), p,
						$vdisplay
					)
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

		my $up = div({-class=>'navup'}, $totop . ' > ' . makeup('repositories', $trans->{'repositories'}->{$lang}));
		#$up .= prev_next_card( $card, $previous_id, $prev_name, $next_id, $next_name );

		#fetch types present in this repository
		my $types = request_tab("SELECT ref_nom, orthographe, autorite, quantite, tt.$lang, s.$lang, td.$lang, ec.$lang
										FROM noms_x_types AS nxt
										LEFT JOIN noms_complets AS nc ON nxt.ref_nom = nc.index
										LEFT JOIN types_type AS tt ON ( nxt.ref_type = tt.index )
										LEFT JOIN sexes AS s ON ( nxt.ref_sexe = s.index )
										LEFT JOIN types_depot AS td ON ( nxt.ref_type_depot = td.index )
										LEFT JOIN etats_conservation AS ec ON ( nxt.ref_etat_conservation = ec.index )
										WHERE nxt.ref_lieux_depot = $repository_id
										ORDER BY tt.$lang;",$dbc);

		my $types_tab;
		foreach my $type ( @{$types} ) {
			my @more;
			if ($type->[5]) { push(@more, $type->[5])}
		       	if ($type->[6]) { push(@more, $type->[6])}
			if ($type->[7]) { push(@more, $type->[7])}
			my $pluriel;
			if($type->[3] > 1) { $pluriel = 's'}
			$types_tab .= li({-class=>'exploli'}, "$type->[3] $type->[4]$pluriel $trans->{'of'}->{$lang} " . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$type->[0]"}, i($type->[1]) . " $type->[2]. " . b("(".join(', ',@more).")") ) );
		}

		my $up = span({-class=>'navup'}, $totop ) . '&nbsp; > &nbsp;' . span({-class=>'tolist', -style=>'margin-left: 0;'}, makeup('repositories', $trans->{'repositories'}->{$lang})) . p;

		$fullhtml = 	div({-class=>'explocontent'},
					$up,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{'repository'}->{$lang}),
						div({-class=>'subject'}, "$repository->[0][0]. $repository->[0][1]"), br,
						ul({-class=>'exploul'}, $types_tab)
					)
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
		my $sp_list = request_tab("SELECT orthographe, autorite, txp.ref_taxon FROM taxons_x_periodes AS txp
								LEFT JOIN taxons_x_noms AS txn ON txp.ref_taxon = txn.ref_taxon
								LEFT JOIN statuts AS s ON txn.ref_statut = s.index
								LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
								WHERE s.fr = 'valide' AND txp.ref_periode = $era_id
								AND n.orthographe ILIKE '$alph%'
								ORDER BY LOWER ( orthographe )
								$bornes;",$dbc);

		my $sp_tab;
		if ( scalar @{$sp_list} != 0){
			$sp_tab = h3({-class=>'exploh3'}, $trans->{"SP_ER"}->{$lang});
			$sp_tab .= start_ul({-class=>'exploul'});
			foreach my $sp ( @{$sp_list} ){
				$sp_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$sp->[2]"}, i($sp->[0]) . " $sp->[1]" ) );
			}
			$sp_tab .= end_ul();
		}
		else {
			#$sp_tab = ul({-class=>'exploul'}, li({-class=>'exploli'}, $trans->{"UNK"}->{$lang}));
		}

		my $up = span({-class=>'navup'}, $totop ) . '&nbsp; > &nbsp;' . span({-class=>'tolist', -style=>'margin-left: 0;'}, makeup('eras', $trans->{'eras'}->{$lang})) . p;

		$fullhtml = 	div({-class=>'explocontent'},
					div({-class=>'carddiv'},
						$up,
						h2({-class=>'exploh2'}, $trans->{'era'}->{$lang}),
						div({-class=>'subject'}, $era->[1]),
						$sp_tab
					)
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
			$sp_tab = h2({-class=>'exploh2'},  $trans->{"SP_RE"}->{$lang});
			$sp_tab .= h4({-class=>'exploh4'}, "$size $trans->{'species(s)'}->{$lang}");
			$sp_tab .= start_ul({-class=>'exploul'});
			foreach my $sp ( @{$sp_list} ){
				$sp_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$sp->[0]"}, i($sp->[1]) . " $sp->[2]" ) . "$sp->[3]" );
			}
			$sp_tab .= end_ul();
		}
		else {
			#$sp_tab = ul({-class=>'exploul'}, li({-class=>'exploli'}, $trans->{"UNK"}->{$lang}));
		}
		
		if ($region->[1]) { $region->[0] .= " ($region->[1])" }

		my $up = span({-class=>'navup'}, $totop ) . '&nbsp; > &nbsp;' . span({-class=>'tolist', -style=>'margin-left: 0;'}, makeup('regions', $trans->{'regions'}->{$lang})) . p;

		$fullhtml = 	div({-class=>'explocontent'},
					$up,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{'region'}->{$lang} ),
						div({-class=>'subject'}, $region->[0] ),
						$sp_tab
					)
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
			$sp_tab .= li({-class=>'exploli'}, 
				#"$sp->[3] : " . 
				a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$sp->[0]"}, i($sp->[1]) . " $sp->[2]" )
				#" ($sp->[5]) " . i("in") . a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$sp->[4]"}, " $pub[1]" ) .
				#getPDF($sp->[4]) 
				);
		}

		if ($agent->[1]) { $agent->[1] = " ($agent->[1])"}

		my $up = span({-class=>'navup'}, $totop ) . '&nbsp; > &nbsp;' . span({-class=>'tolist', -style=>'margin-left: 0;'}, makeup('agents', $trans->{'agents'}->{$lang})) . p;

		$fullhtml = 	div({-class=>'explocontent'},
					$up,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{'agent'}->{$lang}),
						div({-class=>'subject'}, i( $agent->[0] ) . $agent->[1]),
						h3({-class=>'exploh3'}, $trans->{"A_SP"}->{$lang}),
						ul({-class=>'exploul'}, $sp_tab)
					)
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
		$pub_tab = start_ul({-class=>'exploul'});
		foreach my $pub_id ( @{$pub_list} ){
			my $pub = pub_formating($pub_id->[0], $dbc );
			$pub_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$pub_id->[0]"}, "$pub" ) . getPDF($pub_id->[0]) );
		}
		$pub_tab .= end_ul();

		my $up = span({-class=>'navup'}, $totop ) . '&nbsp; > &nbsp;' . span({-class=>'tolist', -style=>'margin-left: 0;'}, makeup('editions', $trans->{'editions'}->{$lang})) . p;

		$fullhtml = 	div({-class=>'explocontent'},
					$up,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{'edition'}->{$lang} ),
						div({-class=>'subject'}, "$edition->[1], $edition->[2], $edition->[3]" ),
						h3({-class=>'exploh3'}, $trans->{"pu_ed"}->{$lang}),
						$pub_tab
					)
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
			$sp_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$sp->[0]"}, i($sp->[1]) . " $sp->[2]" ) . " in $sp->[3]" );
		}

		my $up = span({-class=>'navup'}, $totop ) . '&nbsp; > &nbsp;' . span({-class=>'tolist', -style=>'margin-left: 0;'}, makeup('habitats', $trans->{'habitats'}->{$lang})) . p;

		$fullhtml = 	div({-class=>'explocontent'},
					$up,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{'habitat'}->{$lang}),
						div({-class=>'subject'}, $habitat->[0]),
						h3({-class=>'exploh3'}, $trans->{"SP_HA"}->{$lang}),
						ul({-class=>'exploul'}, $sp_tab)
					)
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
			$sp_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$sp->[0]"}, i($sp->[1]) . " $sp->[2]" ) . ", $sp->[3]" );
		}
		
		my $up = span({-class=>'navup'}, $totop ) . '&nbsp; > &nbsp;' . span({-class=>'tolist', -style=>'margin-left: 0;'}, makeup('localities', $trans->{'localities'}->{$lang})) . p;

		$fullhtml = 	div({-class=>'explocontent'},
					$up,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{'locality'}->{$lang} ),
						div({-class=>'subject'}, "$locality->[0], $locality->[1], $locality->[2]" ),
						h3({-class=>'exploh3'}, $trans->{"SP_LO"}->{$lang}),
						ul({-class=>'exploul'}, $sp_tab)
					)
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

		my $sp_tab = start_ul({-class=>'exploul'});
		foreach my $sp ( @{$sp_list} ){
			$sp_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=species&id=$sp->[0]"}, i($sp->[1]) . " $sp->[2]" ) . " in $sp->[3]" );
		}
		$sp_tab .= end_ul();
		
		my $up = span({-class=>'navup'}, $totop ) . '&nbsp; > &nbsp;' . span({-class=>'tolist', -style=>'margin-left: 0;'}, makeup('captures', $trans->{'captures'}->{$lang})) . p;

		$fullhtml = 	div({-class=>'explocontent'},
					$up,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{'capture'}->{$lang}),
						div({-class=>'subject'}, $capture->[0]),
						h3({-class=>'exploh3'}, $trans->{"SP_CA"}->{$lang}),
						$sp_tab
					)
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

		my $sp_tab = start_ul({-class=>'exploul'});
		foreach my $sp ( @{$sp_list} ){
			$sp_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$sp->[0]"}, i($sp->[1]) . " $sp->[2]" ) );
		}
		$sp_tab .= end_ul();
		
		my $up = span({-class=>'navup'}, $totop ) . '&nbsp; > &nbsp;' . span({-class=>'tolist', -style=>'margin-left: 0;'}, makeup('types', $trans->{'types'}->{$lang})) . p;

		$fullhtml = 	div({-class=>'explocontent'},
					$up,
					div({-class=>'carddiv'},
						h2({-class=>'exploh2'}, $trans->{'type'}->{$lang}),
						div({-class=>'subject'}, $type->[0]),
						h3({-class=>'exploh3'}, $trans->{'names'}->{$lang}),
						$sp_tab
					)
				);
		print $fullhtml;

		$dbc->disconnect;
	}
	else {}
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
	
	$html .= div ({-class=>'navnext'},
			#span({-class=>'navarrow'}, '< '),
			a({-class=>'navlink', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$previous_topic"}, "$trans->{$previous_topic}->{$lang}"),
			span({-class=>'navarrow'}, ' / '),
			a({-class=>'navlink', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$next_topic"}, "$trans->{$next_topic}->{$lang}"),
			#span({-class=>'navarrow'}, ' >')
		);

	return $html;
}

sub alpha_build {

	my ($vletters) = @_;
	
	my @alpha = ( 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z' );

	my @params;
	foreach (keys(%labels)) { if ($_ ne 'alph' and $labels{$_}) { push(@params, $_)}}
	my $args = join('&', map { "$_=$labels{$_}"} @params );
	
	my @links;
	foreach (my $i=0; $i<scalar(@alpha); $i++) { 
		
		unless(exists $vletters->{$alpha[$i]}) { 
			push(@links, span({-class=>'alphaletter'}, span({-class=>'shadow_letter'}, $alpha[$i])));
		}
		elsif($alpha[$i] eq $alph) { 
			push(@links, a({-class=>'alphaletter', -href=>"$scripts{$dbase}$args&alph=$alpha[$i]"}, span({-class=>'xletter'}, $alpha[$i])));
		}
		else {
			push(@links, a({-class=>'alphaletter', -href=>"$scripts{$dbase}$args&alph=$alpha[$i]"}, $alpha[$i]));
		}
	}

	return 	div({-class=>'alphabet'}, @links);
}


sub prev_next_page {
	
	my $html;
	
	#unless ( $from == 0 ){ 
	#	$html .= td( img({-border=>0, -src=>'/explorerdocs/nav_left.png', -style=>'height: 10px; width: 10px;'}) );
	#	my $prev = $from - $to;
	#	my $d = $prev+1;
	#	$html .= td({-style=>'padding: 0 5px;'},  a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$topic&from=$prev&alph=$alph"}, "$d - $from" ) );
	#}
	#if ( $from + $to < $number ){
	#	unless ( $from == 0 ){ 
	#		$html .= td( img({-border=>0, -src=>'/explorerdocs/nav_center.png', -style=>'height: 10px; width: 10px;'}) );  
	#	}
	#	else {  $html .= td({-style=>'padding-left: 20px;'}, '')}
	#	my $next = $from + $to;
	#	my $d1 = $next+1;
	#	my $d2 = $next+$to;
	#	$html .= td({-style=>'padding: 0 5px;'},   a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$topic&from=$next&alph=$alph"}, "$d1 - $d2" ) );
	#	$html .= td( img({-border=>0, -src=>'/explorerdocs/nav_right.png', -style=>'height: 10px; width: 10px;'}) );
	#}

	return $html;
}

sub prev_next_card {
	my ( $card, $prev_id, $prev_text, $next_id, $next_text ) = @_;
	my $prev_next_card;
	
	if ( $prev_id ){
		$prev_next_card .= a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$card&id=$prev_id"}, $prev_text );
	} 
	if ( $next_id ){
		if ($prev_id) { $prev_next_card .= '&nbsp; / &nbsp;' }
		$prev_next_card .= a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$card&id=$next_id"}, $next_text );
	}
	return div({-class=>'navnext'}, '< ' . $prev_next_card . ' >');
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
	my $webmaster = $conf->{TRAD_WMR};
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
sub db_connection {
	my ( $conf ) = @_;
	my $rdbms  = $conf->{DEFAULT_RDBMS};
	my $server = $conf->{DEFAULT_SERVER};
	my $db     = $conf->{DEFAULT_DB};
	my $port   = $conf->{DEFAULT_PORT};
	my $login  = $conf->{DEFAULT_LOGIN};
	my $pwd    = $conf->{DEFAULT_PWD};
	my $webmaster = $conf->{DEFAULT_WMR};
	if ( my $connect = DBI->connect("DBI:$rdbms:dbname=$db;host=$server;port=$port",$login,$pwd) ){
		return $connect;
	}
	else { # connection failed
		my $error_msg .= $DBI::errstr;

		$fullhtml = 	div({-class=>'subject'},  {-class=>'warning'}, "Database connection error");
		
		print $fullhtml;
			
		return undef;
	}
}

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
	my @alpha = ( 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z' );
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
					$authors .= "$pre_authors->[$i][0] & ";
				}
			}
			
		}
		else {
			$authors = "$pre_authors->[0][0] " . i('et al.');
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
		#$pre_pub->[1] =~ s/^(.{1,20}).+$/$1/;
		#$publication = "$author ($pre_pub->[2]$letter) $pre_pub->[1]...";
	}
	
	$abrev = "$author ($pre_pub->[2]$letter)";
	
	return ( $publication, $abrev );
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
	my ($pub_type) = @{	request_row($typereq,$dbc)	};
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
		$author_str = span({-class=>'pub_auteurs'},join(', ',@authors)." & $pub->{$index}->{'auteurs'}->{$nb_authors}->{'nom'} $pub->{$index}->{'auteurs'}->{$nb_authors}->{'prenom'}");
	} else {
		$author_str = span({-class=>'pub_auteurs'},"$pub->{$index}->{'auteurs'}->{$nb_authors}->{'nom'} $pub->{$index}->{'auteurs'}->{$nb_authors}->{'prenom'}");
	}
			
	my @strelmt;
	
	# Adapt the reference citation according to the type of publication
	if ($type eq "Article") {
		
		if ($author_str) { push(@strelmt, b($author_str));} else { push(@strelmt,"Authors Unknown");}
		if (my $annee = $pub->{$index}->{'annee'}) { push(@strelmt,"$annee - ");} else { push(@strelmt," - ");}
		if (my $titre = $pub->{$index}->{'titre'}) {
			if (substr($titre, -1) ne '.') { $titre .= '.' }
			push(@strelmt,"$titre ");
		} else { push(@strelmt,"Title unknown.");}
		if (my $revue = $pub->{$index}->{'revue'}) { push(@strelmt,i($revue));}
		if (my $vol = $pub->{$index}->{'volume'}) {
			$vol = $vol;
			if (my $fasc = $pub->{$index}->{'fascicule'}) { $vol .= "($fasc)";}
			if ($xpage) {
				if (my $cards = $pub->{$index}->{'page_debut'}) {
					push(@strelmt,"$vol:");
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf";}
					push(@strelmt,"$cards [$xpage].");
				} else {
					push(@strelmt,"$vol [$xpage].");
				}
			} else {
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
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf"; }
					push(@strelmt,"$cards [$xpage].");
				}
			}
			else {
				if (my $cards = $pub->{$index}->{'page_debut'}) {
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf"; }
					push(@strelmt,"$cards.");
				}
			}
		}
	}
	
	elsif ($type eq "Book") {

		if ($author_str) { push(@strelmt, b($author_str));} else { push(@strelmt,"Authors Unknown");}
		if (my $annee = $pub->{$index}->{'annee'}) { push(@strelmt,"$annee - ");} else { push(@strelmt," - ");}
		if (my $titre = $pub->{$index}->{'titre'}) { push(@strelmt,i($titre).".");} else { push(@strelmt,i("Title unknown."));}
		if (my $vol = $pub->{$index}->{'volume'}) { 
			if ($xpage) {
				if (my $cards = $pub->{$index}->{'page_debut'}) {
					push(@strelmt, "$vol:"); 
					if ($cards == 1 or $cards eq 'i' or $cards eq 'I') { 
						if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards = "$cardf pp.";}
					}
					else {
						if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf.";}
					}
					push(@strelmt,"$cards [$xpage]");
				} else {
					push(@strelmt, "$vol [$xpage].");
				}
			}
			else {
				if (my $cards = $pub->{$index}->{'page_debut'}) {
					push(@strelmt, "$vol:"); 
					if ($cards == 1 or $cards eq 'i' or $cards eq 'I') { 
						if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards = "$cardf pp.";}
					}
					else {
						if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf.";}
					}
					push(@strelmt,"$cards");
				} else {
					push(@strelmt, "$vol.");
				}
			}
		} else {
			if ($xpage) {
				if (my $cards = $pub->{$index}->{'page_debut'}) {
					if ($cards == 1 or $cards eq 'i' or $cards eq 'I') { 
						if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards = "$cardf pp.";}
					}
					else {
						if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf";}
					}
					push(@strelmt,"$cards [$xpage]");
				}
			}
			else {
				if (my $cards = $pub->{$index}->{'page_debut'}) {
					if ($cards == 1 or $cards eq 'i' or $cards eq 'I') { 
						if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards = "$cardf pp.";}
					}
					else {
						if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf";}
					}
					push(@strelmt,"$cards");
				}
			}
		}
		if (my $edit = $pub->{$index}->{'edition'}) {
			if (my $ville = $pub->{$index}->{'ville'}) { 
				$edit .= ", $ville"; 
				if (my $pays = $pub->{$index}->{'pays'}) {
					$edit .= " ($pays)";
				}
			}
			unless (substr($edit,-1) eq ".") { $edit .= ".";}
			push(@strelmt,$edit);
		}
	}

	elsif ($type eq "In book") {

		if ($author_str) { push(@strelmt, b($author_str));} else { push(@strelmt,"Authors Unknown");}
		if (my $annee = $pub->{$index}->{'annee'}) { push(@strelmt,"$annee - ");} else { push(@strelmt," - ");}
		if (my $titre = $pub->{$index}->{'titre'}) { push(@strelmt,"$titre.");} else { push(@strelmt,i("Title unknown."));}
		push(@strelmt,"In:");
				
		my $nb_authors_livre = $pub->{$index}->{'nbauteurslivre'};
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
		
		if ($book_author_str) { push(@strelmt,$book_author_str);} else { push(@strelmt,"Book Authors Unknown");}
		if (my $annee = $pub->{$index}->{'anneelivre'}) { push(@strelmt,"$annee - ");} else { push(@strelmt," - ");}
		if (my $titre = $pub->{$index}->{'titrelivre'}) { push(@strelmt,i("$titre,"));} else { push(@strelmt,i("Title unknown,"));}
		if (my $vol = $pub->{$index}->{'volumelivre'}) { push(@strelmt, "$vol.");}
		if (my $edit = $pub->{$index}->{'edition'}) {
			if (my $ville = $pub->{$index}->{'ville'}) { 
				$edit .= ", $ville"; 
				if (my $pays = $pub->{$index}->{'pays'}) {
					$edit .= " ($pays)";
				}
			}
			unless (substr($edit,-1) eq ".") { $edit .= ".";}
			push(@strelmt,$edit);
		}
		if ($xpage) {
			if (my $cards = $pub->{$index}->{'page_debut'}) {
				if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf.";}
				push(@strelmt,"p. $cards [$xpage]");
			}
		}
		else {
			if (my $cards = $pub->{$index}->{'page_debut'}) {
				if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf.";}
				push(@strelmt,"p. $cards");
			}
		}

	}
	
	elsif ($type eq "Thesis") {

		if ($author_str) { push(@strelmt, $author_str );} else { push(@strelmt,"Authors Unknown");}
		if (my $annee = $pub->{$index}->{'annee'}) { push(@strelmt,"$annee - ");} else { push(@strelmt," - ");}
		if (my $titre = $pub->{$index}->{'titre'}) { push(@strelmt,i($titre).".");} else { push(@strelmt,i("Title unknown."));}
		push(@strelmt,"Thesis.");
		if ($xpage) {
			if (my $cards = $pub->{$index}->{'page_debut'}) {
				if ($cards == 1 or $cards eq 'i' or $cards eq 'I') { 
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards = "$cardf pp.";}
				}
				else {
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf.";}
				}
				push(@strelmt,"$cards [$xpage]");
			}
		}
		else {
			if (my $cards = $pub->{$index}->{'page_debut'}) {
				if ($cards == 1 or $cards eq 'i' or $cards eq 'I') { 
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards = "$cardf pp.";}
				}
				else {
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf.";}
				}
				push(@strelmt,"$cards");
			}
		}
		if (my $edit = $pub->{$index}->{'edition'}) {
			if (my $ville = $pub->{$index}->{'ville'}) { 
				$edit .= ", $ville"; 
				if (my $pays = $pub->{$index}->{'pays'}) {
					$edit .= " ($pays)";
				}
			}
			unless (substr($edit,-1) eq ".") { $edit .= ".";}
			push(@strelmt,$edit);
		}
	}
	else {
		
		if ($author_str) { push(@strelmt, b($author_str));} else { push(@strelmt,"Authors Unknown");}
		if (my $annee = $pub->{$index}->{'annee'}) { push(@strelmt,"$annee - ");} else { push(@strelmt," - ");}
		if (my $titre = $pub->{$index}->{'titre'}) {
			if (substr($titre, -1) ne '.') { $titre .= '.' }
			push(@strelmt,"$titre ");
		} else { push(@strelmt,"Title unknown.");}
		if (my $revue = $pub->{$index}->{'revue'}) { push(@strelmt,i($revue));}
		if (my $vol = $pub->{$index}->{'volume'}) {
			$vol = $vol;
			if (my $fasc = $pub->{$index}->{'fascicule'}) { $vol .= "($fasc)";}
			
			if ($xpage) {
				if (my $cards = $pub->{$index}->{'page_debut'}) {
					push(@strelmt,"$vol:");
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf";}
					push(@strelmt,"$cards [$xpage].");
				} else {
					push(@strelmt,"$vol [$xpage].");
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
					push(@strelmt,"$cards [$xpage].");
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
			
			my $req = "SELECT DISTINCT t.index, nc.orthographe, nc.autorite, s.en, r.en, nc.index
				FROM taxons AS t 
				LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
				LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				LEFT JOIN rangs AS r ON t.ref_rang = r.index
				WHERE r.en in ('family', 'genus', 'subgenus', 'species', 'subspecies')
				AND s.en not in ('correct use')
				AND txn.ref_nom = $id
				ORDER BY nc.orthographe;";
								
			$sth = $dbc->prepare($req);					
			
			$sth->execute( );
			my ( $taxonid, $name, $autority, $status, $rank, $nameid );
			$sth->bind_columns( \( $taxonid, $name, $autority, $status, $rank, $nameid ) );
			
			my $nb = $sth->rows;
			if ( $nb == 0 ) {
				$content .= div({-class=>'subject'},  $trans->{'noresults'}->{$lang} . " : id = $id");
			}
			if ( $nb == 1 ) {
				$sth->fetch();
				if ( $status eq 'valid' ) { $card = $rank; $id = $taxonid; } else { $card = 'name'; }
			} else {
				$content .= div({-class=>'subject'},  "$nb $trans->{'match_names'}->{$lang}");
				$content .= start_ul({-class=>'exploul'});
				while ( $sth->fetch() ){
					my $link = '';
					# If the name is a valid name, links to the taxon
					if ( $status eq 'valid' ){
						$link = "$scripts{$dbase}db=$dbase&lang=$lang&card=$rank&id=$taxonid"
					}
					# If the name is not valid, links to the name
					else {
						$link = "$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$nameid"
					}
					$content .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>$link}, i($name) . "&nbsp; " . $autority . "&nbsp; " . b($status) ));
			       }
			       $content .= end_ul();
			       $sth->finish();
			}
		}
		elsif ($searchtable eq 'auteurs') { $card = 'author' }
		elsif ($searchtable eq 'publications') { $card = 'publication' }
		elsif ($searchtable eq 'pays') { $card = 'country' }
		elsif ($searchtable eq 'plantes') { $card = 'plant' }
		elsif ($searchtable eq 'noms_vernaculaires') { $card = 'vernacular' }
		
		if ($content) {
			print 	div({-class=>'explocontent'},
				div({-class=>'navup'}, $totop ),
				div({-class=>'tolist'}, '&nbsp;'),
				div({-class=>'carddiv'}, $content )
			);
		}
		else {
			$states{$card}->();
		}
	}
	elsif ($search) {
		
		$searchtable = $searchtable ? $searchtable : 'noms_complets';
		
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
		elsif ($searchtable eq 'plantes') {
			$req = "SELECT index, get_host_plant_name(index) AS fullname FROM plantes WHERE index in (SELECT DISTINCT ref_plante FROM taxons_x_plantes) AND get_host_plant_name(index) ~* '^$query\$' ORDER BY fullname;";
			$xcard = 'plant';
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
			$query = "<b><span class=\"pub_auteurs\">$query";
			foreach (@{$pubids}) {
				my $str = pub_formating($_, $dbc);
				if ($str =~ m/^$query$/i) {
					$publist .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$xcard&id=".$_}, $str));
					$xid = $_;
					$nbresults++;
				}
			}
		}					
				
		if ( $nbresults ){
			if ( $nbresults > 1 ){
				$content .= div({-class=>'subject'},  "$nbresults $trans->{'match_names'}->{$lang}") . p;
				$content .= start_ul({-class=>'exploul'});
				
				if ($searchtable eq 'noms_complets') {
					while ( $sth->fetch() ){
						my $link = '';
						# If the name is a valid name, links to the taxon
						if ( $status eq 'valid' ){
							$link = "$scripts{$dbase}db=$dbase&lang=$lang&card=$rank&id=$taxonid"
						}
						# If the name is not valid, links to the name
						else {
							$link = "$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$nameid"
						}
						$content .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>$link}, i($name) . "&nbsp; " . $autority . "&nbsp; " . b($status) ));
					}
				}
				elsif ($searchtable eq 'publications') {
					$content .= $publist;
				}
				else {
					while ( $sth->fetch() ){
						$content .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$xcard&id=$xid"}, $xlabel));
					}
				}

				if ($sth) { $sth->finish(); }
				$content .= end_ul();
			}
			else {
				if ($sth) { $sth->fetch(); }
				if ($searchtable eq 'noms_complets') {
					if ( $status eq 'valid' ){
						$card=$rank; $id=$taxonid;
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
			$content .= 	div({-class=>'subject'},  $trans->{'noresults'}->{$lang} . " : " . $query );
	       }
	       
	       if($nbresults != 1) {
			$fullhtml =  	div({-class=>'explocontent'},
					div({-class=>'navup'}, $totop ),
					div({-class=>'tolist'}, '&nbsp;'),
					div({-class=>'carddiv'}, $content )
			);
			
			print $fullhtml;
	       }
	       else {
		       $states{$card}->();
	       }
	}
	else { 
		$fullhtml =  	div({-class=>'explocontent'}, 
					div({-class=>'navup'}, $totop ),
					div({-class=>'tolist'}, '&nbsp;'),
					div({-class=>'carddiv'}, div({-class=>'subject'},  $trans->{'noresults'}->{$lang} . " no searchstring given"))
				);
		print $fullhtml;
	}
}
