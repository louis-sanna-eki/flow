package TaxalifeFonc;

use Carp;
use strict;
use warnings;
use DBI;
use CGI qw (-no_xhtml :standard);
use CGI::Carp qw (fatalsToBrowser warningsToBrowser);

BEGIN {
	use Exporter   ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	
	# On défini une version pour les vérifications
	#$VERSION     = 1.00;
	# Si vous utilisez RCS/CVS, ceci serais préférable
	# le tout sur une seule ligne, pour MakeMaker
	#$VERSION = do { my @r = (q$Revisio: XXX $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };
	
	@ISA         = qw(Exporter);
	@EXPORT      = qw(&get_connection_params &read_lang &db_connection &request_tab &request_hash &request_row &getTaxonomists &formatName &getNothonyms &getEunymsFromValid &formatNamesSpecies &getSpeciesTyp &searchLastValidity &getMorphonyms &getHomonyms &getArcheo &getPeriodValiditymorpho &getLapsValidityEunym &getUsageFromUsage &getMorphonym);
	%EXPORT_TAGS = ();
	
	# vos variables globales a être exporter vont ici,
	# ainsi que vos fonctions, si nécessaire
	@EXPORT_OK   = qw();
}
    
my $dbconnect = db_connection(get_connection_params("/etc/flow/nomendb.conf"));
# Les globales non exportees iront la
use vars      qw(&get_connection_params &read_lang &db_connection &request_tab &request_hash &request_row &getTaxonomists &formatName &getNothonyms &getEunymsFromValid &formatNamesSpecies &getSpeciesTyp &searchLastValidity &getMorphonyms &getHomonyms &getArcheo &getPeriodValiditymorpho &getLapsValidityEunym &getUsageFromUsage &getMorphonym);

# Initialisation de globales, en premier, celles qui seront exportées
#$Variable
#%Hash = ();

# Toutes les lexicales doivent être crées avant
# les fonctions qui les utilisent.

# les lexicales privées vont là

# Voici pour finir une fonction interne a ce fichier,
# Appelée par &$priv_func;  elle ne peut être prototyp�e.
#my $priv_func = sub {}

# faites toutes vos fonctions, exporté ou non;
# n'oubliez pas de mettre quelque chose entre les {}
#sub function     {}

################################################ FONCTIONS #######################################
sub get_connection_params {
	
	my ($config_file) = @_;
	
	# read config file
	my $config = { };
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
		
		return $config;
	}
	else {
		die "No configuration file could be found\n";
	}
}

# Read localization from translation DB
####################################################################
sub read_lang { 
	my ( $conf ) = @_;
	my $tr = { };
	my $login  = $conf->{DEFAULT_LOGIN};
	my $pwd    = $conf->{DEFAULT_PWD};
	my $webmaster = $conf->{DEFAULT_WMR};
	if ( my $dbc = DBI->connect("DBI:Pg:dbname=traduction;host=localhost;port='5432'",$login,$pwd) ){
		$tr = $dbc->selectall_hashref("SELECT id, en FROM traductions;", "id");
		$dbc->disconnect; # disconnection
		return $tr;
	}
	else { # connection failed
		my $error_msg .= $DBI::errstr;
		
		die $error_msg;
	}
}


# Database connection functions
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
		return ($connect);
	}
	else { # connection failed
		my $error_msg = $DBI::errstr;
		die $error_msg;
	}
}

# submit query in sql (return a two dimensions array ref)
###################################################################################
sub request_tab {
	my ($req,$dbh,$dim) = @_; # get query
	my $i = 0;
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

# submit query in sql (return a two dimensions array ref)
###################################################################################
sub request_hash {
	my ($req,$dbh,$key_field) = @_; # get query
	my $i = 0;
	my $hash_ref = ();
	if ( my $sth = $dbh->prepare($req) ){ # prepare
		if ( $sth->execute() ){ # execute
			
			unless ($hash_ref = $sth->fetchall_hashref( $key_field )) { die "Could'nt fetch all in hash: $DBI::errstr\n" }
			$sth->finish(); # finalize the request

		}
		else { die "Could'nt execute sql request: $DBI::errstr\n--$req--\n" } # Could'nt execute sql request
	} else { die "Could'nt prepare sql request: $DBI::errstr\n" } # Could'nt prepare sql request

	return $hash_ref;
}

# submit sql query (return a row)
###################################################################################
sub request_row {
	my ($req,$dbh) = @_; # get query
	my $i = 0;
	my $row_ref;

	unless ( $row_ref = $dbh->selectrow_arrayref($req) ){ # prepare, execute, fetch row
			die "Could'nt execute sql request: $DBI::errstr\n--$req--\n" # Could'nt execute sql request
	}
	return $row_ref;
}

#sub func4()  {}

############################################### TOUVER LES TAXONOMISTES #####################################
sub getTaxonomists {
	
	my ($index,$type) = @_;
	
	my $bool;
	my $taxonomists;
	
	# 
	if ($type eq 'auteurs') { $bool = 'TRUE' }
	elsif ($type eq 'reviseurs') { $bool = 'FALSE' }
	else { die "argument error get_taxonomists($type)"; }
	
	# recupere tous les noms et prenoms des taxonomistes	
	if ($index) {
	$taxonomists = request_tab ("SELECT t.nom FROM taxonomistes AS t 
	LEFT JOIN noms_x_taxonomistes as nt ON nt.ref_taxonomiste = t.index 
	WHERE nt.ref_nom = $index 
	AND nt.auteur= $bool ORDER BY nt.position;", $dbconnect, 2);
	}
	
	# creation de la liste autority
	my @taxonomist;
	
	# met la liste (regroupe les element de @{$aut}) dans une chaine de caracteres a la fin du tableau @autority
	foreach my $tax (@{$taxonomists}) {
		push (@taxonomist,join (' ',@{$tax}));
	}
		
	# lie les taxonomistes par une ,
	my $taxonomist = join (',',@taxonomist);
	
	# retourne les taxonomistes 
	return ($taxonomist);
}




##################################################### FORMATER UN NOM SUBSTANTIF ################################
sub formatName {
	
	my ($name) = @_;
	
	my $aut = getTaxonomists ($name->{'index'},'auteurs');
		
	my $formatedsub = i($name->{'genre'})." $aut, $name->{'annee_princeps'}";
		 
	return  $formatedsub;
}

############################################## EXTRAIRE DES NOMS INCORRECTS ##########################################	

sub getNothonyms {
	
	my ($gid, $dispo) = @_;
	my $cond;
	
	if ($dispo eq 'disponible') {
		$cond = 'disponible';
	}
	elsif ($dispo eq 'indisponible') {
		$cond = 'indisponible';
	}
	elsif ($dispo eq 'nudum') {
		$cond = 'nomen nudum';
	}
	else { die "wrong argument $cond for getNothonyms() function \n"; }
	
	# recherche des noms incorrects 	
	my $nothonyms = request_hash ("	SELECT ne.index, ng.orthographe as genre, ne.orthographe as espece, ne.annee_princeps,ne.parentheses,
									ne.annee_validite,ne.ref_protonyme as proto, ne.page_erreur as erreur
									FROM noms as ne
									LEFT JOIN noms AS ng ON ne.ref_nom_parent = ng.index
									LEFT JOIN  taxons_x_noms AS txn ON txn.ref_nom = ne.index
									WHERE ng.index = '$gid' AND ne.categorie_morphonyme like '%nothonyme%'
									AND ne.disponibilite = '$cond';", $dbconnect, "index");
		
  return $nothonyms;
}
################################################# EXTRAIRE DES NOMS CORRECTS #######################################

sub getEunymsFromValid {

	my ($gid) = @_;
	
	my $eunyms = request_hash (" 	SELECT ne.index, ng.orthographe as genre , ne.orthographe as espece, ne.annee_princeps, 
									ne.parentheses, ne.annee_validite, ne.ref_protonyme as proto, ne.page_erreur as erreur, ne.categorie_morphonyme as propriete 
									FROM noms AS ne
									LEFT JOIN  noms AS ng ON ne.ref_nom_parent = ng.index
									LEFT JOIN  taxons_x_noms AS txn ON txn.ref_nom = ne.index
									LEFT JOIN  taxons AS t ON t.index = txn.ref_taxon
									WHERE ng.index = '$gid' AND usage= 'valide'	",$dbconnect,"index");
	
	return $eunyms;
}
################################################# FORMATER UN NOM D'ESPECES ####################################
	
sub formatNamesSpecies {
		
	my ($names) = @_ ;
	
	my $namespe;
	
	my $aut = getTaxonomists ($names->{'index'},'auteurs');
	my $rev = getTaxonomists ($names->{'index'},'reviseurs');
	
	if ($names->{'parentheses'}) {
			$namespe = span ({-class=> 'italic'}, "$names->{'genre'} $names->{'espece'}")." ($aut, $names->{'annee_princeps'}) $rev, $names->{'annee_validite'}";
	}
	else {
		$namespe = span ({-class=> 'italic'}, "$names->{'genre'} $names->{'espece'}")." $aut, $names->{'annee_princeps'} ";
	}
	
	 return $namespe;
}	

######################################### EXTRAIRE ESPECE TYPE DU GENRE ######################################################################

sub getSpeciesTyp {
	
	my ($gid) = @_;
	
	# recupere l'espece type du genre etudie
	my $speciestyp = request_hash ("SELECT ne.index, ng.orthographe as genre,ne.orthographe as espece,ne.annee_princeps, ne.parentheses, ne.annee_validite 
		FROM noms as ne
		LEFT JOIN noms AS ng ON ne.ref_nom_parent = ng.index
		WHERE ne.ref_type = '$gid';", $dbconnect, "index");
		
	return $speciestyp;
}

####################################### EXTRAIRE ANNEE DE DERNIERE VALIDITE ################################	

sub searchLastValidity {
	
	my ($eunyms) = @_; 
	my @lastval;
	
	
	foreach my $eunymid (keys %{$eunyms}) {
		if ($eunyms->{$eunymid}{'parentheses'}) {
				push (@lastval, join (' ',$eunyms->{$eunymid}{'annee_validite'}));
			}
			else {
				push (@lastval, join (' ',$eunyms->{$eunymid}{'annee_princeps'}));
			}
	}	
	 @lastval = sort {$a <=> $b} @lastval;
	 
		
	return $lastval[0];
}

########################################## EXTRAIRE LEs NOMS CORRECTS SuIVANTS ###########################################

sub getMorphonyms {

	my ($morpho, $chrono, $dispo) = @_;
	my $morphos;
	my $essai;
	
	if ($dispo eq 'disponible') {
		$essai = 'disponible';
	}
	elsif ($dispo eq 'indisponible') {
		$essai = 'indisponible';
	}
	else { die "wrong argument $essai for getMorphonyms() function \n"; }
	
	my $req = "	SELECT  ne.index, ng.orthographe as genre ,ne.orthographe as espece ,
				ne.annee_princeps, ne.parentheses, ne.annee_validite, ne.page_erreur as erreur, ne.categorie_morphonyme as propriete 
				FROM noms AS ne
				LEFT JOIN noms as ng On ng.index = ne.ref_nom_parent 
				WHERE ne.disponibilite = '$essai' ";
	my $cond;
			
	if ($morpho->{'proto'}) { 
		$req .= "AND (ne.ref_protonyme = $morpho->{'proto'} "; 
		$cond = "OR ne.index = $morpho->{'proto'})"; 
	}
	else { 
		$req .= "AND (ne.ref_protonyme = $morpho->{'index'} ";
		$cond = "OR ne.index = $morpho->{'index'})"; 
	}
			
	if ($chrono eq 'all') {	
			$req .= $cond;
	}
	elsif ($chrono eq 'next') 	{
			# recherche de l'aponyme suivant si aponyme
			$req .= "AND ne.annee_validite > $morpho->{'annee_validite'})";
	}
	elsif ($chrono eq 'previous') { 
			# recherche de l'aponyme suivant si aponyme
			if ($morpho->{'proto'}) { 
				$req .= "OR ne.index = $morpho->{'proto'})";
			}
			else {$req .= ")";}
			$req .= "AND ne.annee_validite < $morpho->{'annee_validite'}";
	}
	else { die "wrong argument $chrono for getMorphonyms() function \n"; }
	
	$morphos = request_hash ($req, $dbconnect, "index");
			
	return $morphos;				
	
}
################################################ EXTRAIRE LES HOMONYMES PLUS RECENTS DES NOMS CORRECTS ####################################

sub getHomonyms {

	my ($eunym, $statut, $chrono) = @_;
	
	my ($eutime, $homotimecond, $statutcond);
	
	if ($statut eq 'homonymie primaire' or $statut eq 'homonymie secondaire')  { $statutcond = "nxn.statut_nominal = '$statut'"; }
	elsif ($statut eq 'all_statut')  { $statutcond = "nxn.statut_nominal like 'homonymie%' "; }
	else { die "wrong argument $statut for getHomonyms() function \n"; }
	
	unless ($chrono eq 'all_time') {
		if ($chrono eq 'plus_anciens') { 
			$homotimecond = "AND ne.index = nxn.ref_nom_plus_ancien";
			$eutime = "ref_nom_plus_recent";
		}
		elsif ($chrono eq 'plus_recents') { 
			$homotimecond = "AND ne.index = nxn.ref_nom_plus_recent";
			$eutime = "ref_nom_plus_ancien";
		}
		else { 
			 die "wrong argument $chrono for getHomonyms() function \n"; 
		}
	}	
	
	my $homonyms = request_hash ("	SELECT  ne.index, ng.orthographe as genre ,ne.orthographe as espece ,ne.annee_princeps, ne.parentheses, ne.annee_validite 
									FROM noms as ne
									LEFT JOIN noms AS ng ON ne.ref_nom_parent = ng.index
									LEFT JOIN noms_x_noms as nxn ON nxn.$eutime = $eunym->{'index'}
									WHERE $statutcond
									$homotimecond;", $dbconnect, "index");

	return $homonyms;
}
############################################# EXTRAIRE LES NOMS ANCIENS DES NOMS CORRECTS ###################################

sub getArcheo {

	my ($eunym, $statut, $chrono) = @_;
	
	my ($eutime, $homotimecond, $statutcond);
	
	if ($statut eq 'neonymie' or $statut eq 'nom de remplacement par synonymie')  { $statutcond = "nxn.statut_nominal = '$statut'"; }
	else { die "wrong argument $statut for getArcheo() function \n"; }
	
	if ($chrono eq 'plus_ancien') { 
		$homotimecond = " ne.index = nxn.ref_nom_plus_ancien";
		$eutime = "ref_nom_plus_recent";
	}
	elsif ($chrono eq 'plus_recent') { 
		$homotimecond = " ne.index = nxn.ref_nom_plus_recent";
		$eutime = "ref_nom_plus_ancien";
	}
	else { die "wrong argument $chrono for getHomonyms() function \n"; }	
	
		my $archeonyme = request_hash ("SELECT  ne.index, ng.orthographe as genre ,ne.orthographe as espece ,ne.annee_princeps, ne.parentheses, ne.annee_validite 
			FROM noms as ne
			LEFT JOIN noms AS ng ON ne.ref_nom_parent = ng.index
			LEFT JOIN noms_x_noms as nxn ON $homotimecond
			WHERE nxn.$eutime = $eunym->{'index'} AND $statutcond;", $dbconnect, "index");

	return $archeonyme;

}	


############################################### PERIODE VALIDITE ###############################################

sub getPeriodValiditymorpho {

	my ($nextmorphos, $notho) = @_ ;
	
	my $period;
	
	if ($nextmorphos->{'parentheses'} and !$notho->{'parentheses'}) {
			$period = ($nextmorphos->{'annee_validite'}) - ($notho->{'annee_princeps'});
		}
	elsif ($nextmorphos->{'parentheses'} and $notho->{'parentheses'}) {
			$period = ($nextmorphos->{'annee_validite'})-($notho->{'annee_validite'});
		}
	
	return $period;
}	
######################################## PERIODE VALIDITE NOMS CORRECTS ##################################

sub getLapsValidityEunym {

	my ($eunym) = @_ ;
	
	my $duree;
	
	if ($eunym->{'parentheses'}) {
			$duree = 2006- ($eunym->{'annee_validite'});
		}
	elsif (!$eunym->{'parentheses'}) {
			$duree = 2006 - ($eunym->{'annee_princeps'});
		}
	
	 return $duree;
}	
###################################### CHERCHER LES SYNONYMES D'UN VALIDE #############################################

sub getUsageFromUsage {

	my($usage, $usage2, $gid) = @_;
	
	my $usag = request_hash ("	SELECT syn.index, syn.orthographe as genre , syn.annee_princeps				
								FROM noms as syn
								WHERE syn.index IN (SELECT ref_nom FROM taxons_x_noms WHERE ref_taxon = (SELECT distinct ref_taxon FROM taxons_x_noms WHERE ref_nom = '$gid' AND usage = '$usage2')
								AND usage = '$usage');" ,$dbconnect, "index");
								
	return $usag;

}

########################################## EXTRAIRE UN MORPHONYME ###########################################

sub getMorphonym {

	my ($nothonym, $chrono) = @_;
	
	my $cond;
	my $morpho;
	
	if ($chrono eq 'next') { $cond = " min(annee_validite)"}
	elsif ($chrono eq 'last') { $cond = " max(annee_validite)"}
	else { die "wrong argument $chrono for getMorphonym() function \n"; }
		
	
	my $req = "SELECT  ne.index, ng.index as gindex, ng.annee_princeps as gannee, ng.orthographe as genre ,ne.orthographe as espece ,ne.annee_princeps, ne.parentheses, ne.annee_validite 
			FROM noms as ne
			LEFT JOIN noms AS ng ON ne.ref_nom_parent = ng.index
			WHERE ne.orthographe = '$nothonym->{'espece'}'";
												
	if ($nothonym->{'parentheses'}) {
		# recherche de l'aponyme suivant si aponyme
		
		$req .= "	AND ne.annee_validite = (SELECT $cond FROM noms 
					WHERE ref_protonyme = $nothonym->{'proto'} AND annee_validite > $nothonym->{'annee_validite'});"; 						
	}
		
	else {
		# recherche de l'aponyme  suivant si proto	
		
		$req .= "	AND ne.ref_protonyme = $nothonym->{'index'} AND ne.annee_validite = (SELECT $cond FROM noms
					WHERE transfert = TRUE AND ref_protonyme = $nothonym->{'index'});";			
	}
	
	$morpho = request_hash ($req, $dbconnect, "index");
	return $morpho;				
	
}

##########################################################################################################
END { }      # (destructeurs globaux)

1;
