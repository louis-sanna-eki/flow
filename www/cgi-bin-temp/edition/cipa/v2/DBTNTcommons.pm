package DBTNTcommons;

use Carp;
use strict;
use warnings;
use Style qw ($conf_file $background $css $jscript_imgs $jscript_for_hidden);
use DBI;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use DBCommands qw (get_connection_params read_lang db_connection request_hash request_tab request_row);


BEGIN {
	use Exporter   ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	
	@ISA         = qw(Exporter);
	@EXPORT      = qw(&pub_formating &get_pub_params &make_thesaurus);
	%EXPORT_TAGS = ();
	
	@EXPORT_OK   = qw();
}
    

# Les globales non exportees iront la
use vars      qw(&pub_formating &get_pub_params &make_thesaurus);

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
		$hashlabels .= $hash.'["'.$intitule.'"] = ' . $row->[0] . ';';
	}
	${$onload} .= " var $hash = {}; $hashlabels ";
}

# Get all necessary informations of a publication from his index to put it in a hash.
sub get_pub_params {

	my ($dbc, $index) = @_;
		
	# Get the type of the publication
	my $typereq = "SELECT type.en FROM types_publication as type LEFT JOIN publications as p on (p.ref_type_publication = type.index) WHERE p.index = $index;";
			
	my ($pub_type) = @{	request_tab($typereq,$dbc,1)	};
				
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

1;
