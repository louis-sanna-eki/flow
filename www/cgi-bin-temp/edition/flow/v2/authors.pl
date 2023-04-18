#!/usr/bin/perl

use strict;
use warnings;
use diagnostics;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use DBCommands qw (get_connection_params db_connection request_tab request_row request_hash);
use HTML_func qw (html_header html_footer arg_persist);
use DBTNTcommons qw (pub_formating get_pub_params make_thesaurus);
use Style qw ($conf_file $background $rowcolor $css $jscript_imgs $jscript_for_hidden $dblabel $cross_tables);

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
	bgcolor => $background,
	css => $css
);


unless ($action eq 'fusion') {

	my $authors;
	make_hash ($dbc, "SELECT index, nom, prenom FROM auteurs;", \$authors);
					
	my $label = 'auteur ' . p;
	
	$label .= popup_menu(-class=>'phantomTextField', -style=>'padding: 0;', -name=>'author1', values=>['', sort {$authors->{$a} cmp $authors->{$b}} keys(%{$authors})], -labels=>$authors);
	
	$label .= p . "fusionn&#233; avec" . p;
	
	$label .= popup_menu(-class=>'phantomTextField', -style=>'padding: 0;', -name=>'author2', values=>['', sort {$authors->{$a} cmp $authors->{$b}} keys(%{$authors})], -labels=>$authors);

	$label .= p . "puis supprim&#233;";
	
	$label .= p . submit('OK');
	
	
	print 	html_header(\%headerHash),
			div ({-style=>'margin: 15% auto; width: 1000px;'},
				start_form(-name=>'Form', -method=>'post',-action=>url().'?action=fusion'),
					$label,
				end_form()	
			),
			html_footer();
}
else {

	my ($old, $new) = (param('author1'), param('author2'));
		
	if ($old and $new and $old != $new) {
	
		my $req = "BEGIN;
				UPDATE auteurs_x_publications SET ref_auteur = $new WHERE ref_auteur = $old;
				UPDATE noms_x_auteurs SET ref_auteur = $new WHERE ref_auteur = $old;
				DELETE FROM auteurs WHERE index = $old;
				COMMIT;";
		
		my $sth = $dbc->prepare($req) or die "$req ERROR: ".$dbc->errstr;
		
		$sth->execute() or die "$req ERROR: ".$dbc->errstr;
	}

	print 	html_header(\%headerHash),
			
			div ({-style=>'margin: 15% auto; width: 1000px;'},
				
				img{-src=>'/Editor/done.jpg'}, p,
			
				span({-style=>'color: green'}, "Fusion done")
			
			),
			
			html_footer();
}
