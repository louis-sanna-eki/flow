#!/usr/bin/perl
# Connection config
use strict;
use DBI;
#use DBcommands qw(get_connection_params db_connection)
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

#my $bd		= 'flow';
#my $serveur	= 'localhost'; # Il est possible de mettre une adresse IP
##my $identifiant = 'web';      # identifiant 
#my $motdepasse	= 'web@xess';
#my $port	= '';		#Si vous ne savez pas, ne rien mettre


print "Content-type:text/html\r\n\r\n";
print '<html>';
print '<head>';
print '<title>First CGI Program</title>';
print '</head>';
print '<body>';
print '<h2>try connection 2</h2>';

my $config_file = '/etc/flow/flowexplorer.conf';
my $config = get_connection_params($config_file);
my $dbh = db_connection($config);


# Create DB handle object by connecting

#my $dbh = DBI->connect( "DBI:Pg:database=$bd;host=$serveur", 
#    $identifiant, $motdepasse,   ) or die "Connection impossible à la base de données $bd !\n $DBI::errstr";


#my $dbh = DBI->connect( "DBI:Pg:database=$bd;host=$serveur;port=$port", 
#    $identifiant, $motdepasse,   ) or die "Connection impossible à la base de données $bd !\n $DBI::errstr";


my $prep = $dbh->prepare("select * from taxons where createur = 'guest';") or die $dbh->errstr;
$prep->execute() or die "Echec requête\n";
my @row;
while ( @row = $prep->fetchrow ) {
   print "Field : @row\n<BR>";
   }
$prep->finish;
$dbh->disconnect();


print' done<BR>';
print '</body>';
print '</html>';
1;



