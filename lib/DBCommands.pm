package DBCommands;

use Carp;
use strict;
use warnings;
use DBI;

BEGIN {
	use Exporter   ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	
	# On défini une version pour les vérifications
	#$VERSION     = 1.00;
	# Si vous utilisez RCS/CVS, ceci serais préférable
	# le tout sur une seule ligne, pour MakeMaker
	#$VERSION = do { my @r = (q$Revisio: XXX $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };
	
	@ISA         = qw(Exporter);
	@EXPORT      = qw(&get_connection_params &db_connection &request_tab &request_hash &request_row &request_bind &get_title);
	%EXPORT_TAGS = ();
	
	# vos variables globales a être exporter vont ici,
	# ainsi que vos fonctions, si nécessaire
	@EXPORT_OK   = qw();
}


# Les globales non exportees iront la
use vars      qw(&get_connection_params &to_uft8 &db_connection &request_tab &request_hash &request_row &request_bind &get_title);

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
	if ( my $connect = DBI->connect("DBI:$rdbms:dbname=$db;host=$server;port=$port",$login,$pwd,{pg_enable_utf8 => 1}) ){
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

# submit query in sql (return a two dimensions array ref)
###################################################################################
sub request_bind {
	my ($req, $dbh, $cols) = @_; # get query
	
	my $sth;
	
	if ( $sth = $dbh->prepare($req) ){ # prepare
		if ( $sth->execute() ){ # execute
			unless ($sth->bind_columns( @{$cols} )) { die "Could'nt bind columns: $DBI::errstr\n" }
		}
		else { die "Could'nt execute sql request: $DBI::errstr\n--$req--\n" } # Could'nt execute sql request
	} else { die "Could'nt prepare sql request: $DBI::errstr\n" } # Could'nt prepare sql request
	
	return $sth;
}

# submit sql query (return a row)
###################################################################################
sub request_row {
	my ($req,$dbh) = @_; # get query
	my $row_ref;

	unless ( $row_ref = $dbh->selectrow_arrayref($req) ){ # prepare, execute, fetch row
			die "Could'nt execute sql request: $DBI::errstr\n--$req--\n" # Could'nt execute sql request
	}
	return $row_ref;
}

sub get_title {
	
	my ($dbh, $db, $card, $id, $search, $lang, $info, $alpha, $trans) = @_; # get query
		
	my $req;
	my $title;
			
	if ($card eq 'top') {
		$title = 'Topics';
	}
	elsif ($card eq 'taxon' or $card eq 'family' or $card eq 'genus' or $card eq 'species') {
		$req = "SELECT nc.orthographe, nc.autorite FROM noms_complets AS nc LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = nc.index WHERE txn.ref_statut = 1 AND txn.ref_taxon = $id";
	}
	elsif ($card eq 'author') {
		$req = "SELECT a.nom, a.prenom FROM auteurs AS a WHERE a.index = $id";
	}
	elsif ($card eq 'publication') {
		$req = "SELECT p.annee, a.nom, a.prenom FROM publications AS p LEFT JOIN auteurs_x_publications AS axp ON axp.ref_publication = p.index LEFT JOIN auteurs AS a ON a.index = axp.ref_auteur WHERE p.index = $id ORDER BY axp.position";
		my $tab = request_tab($req,$dbh,2);
		my $annee = $tab->[0][0];
		my @authors;
		foreach (@{$tab}) {
			push(@authors, "$_->[1] $_->[2]");
		}
		my $last;
		if (scalar(@authors) > 1) { $last = ' & ' . pop(@authors); }
		$title = join(', ',@authors) . $last . ' ' . $annee;
	}
	elsif ($card eq 'molecular') { $title = ucfirst($trans->{'molecular_data'}->{$lang}); }
	elsif ($card eq 'name') {
		$req = "SELECT nc.orthographe, nc.autorite FROM noms_complets AS nc WHERE nc.index = $id";
	}
	elsif ($card eq 'country') {
		my ($country_id, $taxnameid) = split('XX', $id);
		$req = "SELECT p.$lang FROM pays AS p WHERE p.index = $country_id";
	}
	elsif ($card eq 'plant') {
		$req = "SELECT get_host_plant_name($id);";
	}
	elsif ($card eq 'searching') {
		$title = $search;
	}
	elsif ($card eq 'image') {
		$title = $trans->{'image'}->{$lang};
	}
	elsif ($card eq 'era') {
		$req = "SELECT en FROM periodes WHERE index = $id;";
	}
	elsif ($card eq 'vernacular') {
		$req = "SELECT nom FROM noms_vernaculaires WHERE index = $id";
	}
	elsif ($card eq 'repository') {
		$req = "SELECT nom FROM lieux_depot WHERE index = $id";
	}
	elsif ($card eq 'families') { $title = ucfirst($trans->{'familys'}->{$lang}); }

	elsif ($card eq 'genera') { $title = ucfirst($trans->{'genuss'}{$lang}); }
	elsif ($card eq 'speciess') { $title = ucfirst($trans->{'speciess'}{$lang}); }
	elsif ($card eq 'authors') { $title = ucfirst($trans->{'authors'}{$lang}); }
	elsif ($card eq 'publications') { $title = ucfirst($trans->{'publications'}{$lang}); }
	elsif ($card eq 'names') { $title = ucfirst($trans->{'names'}{$lang}); }
	elsif ($card eq 'countries') { $title = ucfirst($trans->{'countries'}{$lang}); }
	elsif ($card eq 'plants') { $title = ucfirst($trans->{'plants'}{$lang}); }
	elsif ($card eq 'board') { $title = 'Synopsis'; }
	elsif ($card eq 'images' ) { $title = ucfirst($trans->{'images'}{$lang}); }
	elsif ($card eq 'vernaculars' ) { $title = ucfirst($trans->{'vernaculars'}{$lang}); }
	elsif ($card eq 'fossils') { $title = ucfirst($trans->{'fossils'}{$lang}); }	
	elsif ($card eq 'repositories') { $title = ucfirst($trans->{'repositories'}{$lang}); }

	elsif ($info eq 'psylloidea' ) { $title = 'psylloidea'; }
	elsif ($info eq 'contributors' ) { $title = ucfirst($trans->{'contributors'}{$lang}); }
	elsif ($info eq 'projects' ) { $title = ucfirst($trans->{'projects'}{$lang}); }
	elsif ($info eq 'technical' ) { $title = ucfirst($trans->{'tech_key'}{$lang}); }
	elsif ($info eq 'howtocite' ) { $title = ucfirst($trans->{'citation'}{$lang}) }
	elsif ($info eq 'links' ) { $title = ucfirst($trans->{'links'}{$lang}); }
	elsif ($info eq 'contact' ) { $title = ucfirst($trans->{'contact'}{$lang}); }
	
	else { $title = ucfirst($trans->{'websitehome'}{$lang}); }
	
	if ($alpha ne 'NULL') { $title .= " - " . ucfirst($alpha); }
	
	unless ($title) {
		my $tab = request_tab($req,$dbh,2);
		if (scalar( @{$tab})) {
			($title) = join(' ', @{ $tab->[0] });
		}
	}
		
	#if ($db eq 'psylles') { $title = "Psyl'list : " . $title; }
	#else { $title = "$db : " . $title; }
				
	return $title;
}


END { }
1;
