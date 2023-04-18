#!/usr/bin/perl
BEGIN {push @INC, '/var/www/cgi-bin/edition/hefo/'} 
use strict;
use warnings;
use diagnostics;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use DBCommands qw (get_connection_params db_connection request_tab request_row request_hash);
use Conf qw ($conf_file $css html_header html_footer);

my $dbc = db_connection(get_connection_params($conf_file));

sub make_hash {
	my ($dbc, $req, $xhash) = @_;
	my ($xkey, $xvalue, $precise);
	my 	$sth = $dbc->prepare($req);
		$sth->execute();
		$sth->bind_columns( \( $xkey, $xvalue, $precise ) );
	while ($sth->fetch()) {
		${$xhash}->{$xkey} = $xvalue;
		if ($precise) { ${$xhash}->{$xkey} .= " $precise" }
	}
}

my $action = url_param('action');

my %headerHash = (
	titre => "fusion d'auteurs",
	bgcolor => 'transparent',
	css => $css
);


unless ($action eq 'fusion') {

	my $authors;
	make_hash ($dbc, "SELECT index, nom, prenom FROM auteurs;", \$authors);
					
	my $label = 'auteur mal orthographié:' . p;
	
	$label .= popup_menu(-class=>'phantomTextField', -style=>'padding: 0;', -name=>'author1', values=>['', sort {$authors->{$a} cmp $authors->{$b}} keys(%{$authors})], -labels=>$authors);
	
	$label .= p . "orthographe correcte:" . p;
	
	$label .= popup_menu(-class=>'phantomTextField', -style=>'padding: 0;', -name=>'author2', values=>['', sort {$authors->{$a} cmp $authors->{$b}} keys(%{$authors})], -labels=>$authors);
	
	$label .= p . submit('OK');
	
	
	print 	html_header(\%headerHash),
			div ({-style=>'margin: 15% auto; width: 1000px;'},
				start_form(-name=>'Form', -method=>'post', -action=>url().'?action=fusion', -onsubmit=>"return confirm('vérifier soigneusement la requête avant de soumettre. confirmez-vous?');"),
					$label,
				end_form()	
			),
			html_footer();
}
else {

	my ($old, $new) = (param('author1'), param('author2'));
	my $msg;
		
	if ($old and $new and $old != $new) {
	
		my $req = "BEGIN;
				UPDATE auteurs_x_publications SET ref_auteur = $new WHERE ref_auteur = $old;
				UPDATE noms_x_auteurs SET ref_auteur = $new WHERE ref_auteur = $old;
				DELETE FROM auteurs WHERE index = $old;
				COMMIT;";
		
		my $sth = $dbc->prepare($req) or die "$req ERROR: ".$dbc->errstr;
		
		$sth->execute() or die "$req ERROR: ".$dbc->errstr;
		
		$msg = img({-src=>'/Editor/done.jpg'}). p. span({-style=>'color: green'}, "Correction effectuée");
	}
	else { $msg = img({-src=>'/Editor/caution.jpg'}). p. span({-style=>'color: red'}, "Action impossible"); }

	print 	html_header(\%headerHash),
			
			div ({-style=>'margin: 15% auto; width: 1000px;'},
				
				$msg, p,
			
				a({-href=>"authors.pl", -style=>'text-decoration: none; color: navy;'}, 'Retour au menu')
				
			),
			
			html_footer();
}
