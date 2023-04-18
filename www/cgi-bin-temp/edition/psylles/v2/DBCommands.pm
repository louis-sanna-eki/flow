package DBCommands;

use Carp;
use strict;
use warnings;
use DBI;

BEGIN {
	use Exporter   ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	
	# On dÃ©fini une version pour les vÃ©rifications
	#$VERSION     = 1.00;
	# Si vous utilisez RCS/CVS, ceci serais prÃ©fÃ©rable
	# le tout sur une seule ligne, pour MakeMaker
	#$VERSION = do { my @r = (q$Revisio: XXX $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };
	
	@ISA         = qw(Exporter);
	@EXPORT      = qw(&get_connection_params &read_lang &db_connection &request_tab &request_hash &request_row &request_bind);
	%EXPORT_TAGS = ();
	
	# vos variables globales a Ãªtre exporter vont ici,
	# ainsi que vos fonctions, si nÃ©cessaire
	@EXPORT_OK   = qw();
}
    

# Les globales non exportees iront la
use vars      qw(&get_connection_params &read_lang &db_connection &request_tab &request_hash &request_row &request_bind);

# Initialisation de globales, en premier, celles qui seront exportÃ©es
#$Variable
#%Hash = ();

# Toutes les lexicales doivent Ãªtre crÃ©es avant
# les fonctions qui les utilisent.

# les lexicales privÃ©es vont lÃ 

# Voici pour finir une fonction interne a ce fichier,
# AppelÃ©e par &$priv_func;  elle ne peut Ãªtre prototypée.
#my $priv_func = sub {}

# faites toutes vos fonctions, exportÃ© ou non;
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

END { }
1;
