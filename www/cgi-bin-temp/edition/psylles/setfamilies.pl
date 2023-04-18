#!/usr/bin/perl
BEGIN {push @INC, '/var/www/cgi-bin/edition/psylles/'} 
use strict;
use warnings;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use DBCommands qw (get_connection_params db_connection request_tab request_hash);
use Conf qw ($conf_file $css $jscript_for_hidden $dblabel $cross_tables $single_tables html_header html_footer arg_persist $maintitle);

my $config = get_connection_params($conf_file);
my $dbc = db_connection($config, 'EDITOR');

my $taxa = request_tab("SELECT index, family FROM taxons ORDER BY index;", $dbc, 2);

my %headerHash = ( titre => "UPDATE TAXA", css => $css );

foreach (@{$taxa}) {
	unless ($_->[1]) {
		my $req = "UPDATE taxons SET distribution_complete = distribution_complete WHERE index = $_->[0];";
		if ( my $sth = $dbc->prepare($req) ) { if ( $sth->execute() ){ $sth->finish(); } else { die "Execute error: $req ".$dbc->errstr; } } else { die "Prepare error: $req ".$dbc->errstr; }
	}
}	

print html_header(\%headerHash), div({-class=>"wcenter"}, "Job done"), html_footer();

$dbc->disconnect();
exit;

