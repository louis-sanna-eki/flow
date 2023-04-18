#!/usr/bin/perl

use strict;
#use warnings;
use DBI;
use CGI qw( -no_xhtml :standard start_ul); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser ); # display errors in browser
#use CGI::Pretty;
use Date::Format;
use Getopt::Long;
use utf8;

#my $srcdir = "/var/www/html/Documents/4d4life";
my $srcdir = "/var/www/html/Documents/4d4life";

my $base;
my $local;
unless ($base = url_param('db')) { 
	GetOptions("db=s" => \$base);
	if ($base) { $local = 1; } 
}

my $config_file;

my $specialist;
my $scrutinydate;
my $explorer;
my $order;
my $suborder;
my $superfamily;
if ($base eq 'flow') { 
	$config_file = '/etc/flow/flowexplorer.conf';
	$specialist = 'Bourgoin Thierry';
	$scrutinydate = '15/01/2015';
	$explorer = 'http://hemiptera-databases.com/flow';
	$order = 'Hemiptera';
	$suborder = 'Fulgoromorpha';
	$superfamily = 'Fulgoroidea';
	$srcdir .= "/flow";
}
elsif ($base eq 'cool') { 
	$config_file = '/etc/flow/coolexplorer.conf';
	$specialist = 'Soulier-Perkins Adeline';
	$scrutinydate = '15/01/2015';
	$explorer = 'http://hemiptera-databases.com/cool';
	$order = 'Hemiptera';
	$suborder = 'Cicadomorpha';
	$superfamily = 'Cercopoidea';
	$srcdir .= "/cool";
}
elsif ($base eq 'psyllist') {
	$config_file = '/etc/flow/psyllesexplorer.conf';
	$specialist = 'Ouvrard David';
	$scrutinydate = '15/01/2015';
	$explorer = 'http://www.hemiptera-databases.com/psyllist';
	$order = 'Hemiptera';
	$suborder = 'Sternorrhyncha';
	$superfamily = 'Psylloidea';
	$srcdir .= "/psyllist";
}
elsif ($base eq 'strepsiptera') {
	$config_file = '/etc/flow/strepsexplorer.conf';
	$specialist = 'Kathirithamby J.';
	$scrutinydate = '15/01/2015';
	$explorer = 'http://hemiptera.infosyslab.fr/cgi-bin/strepsiptera.pl';
	$order = 'Strepsiptera';
	$suborder = '';
	$superfamily = '';
	$srcdir .= "/strepsiptera";
}
elsif ($base eq 'pelorids') {
	$config_file = '/etc/flow/peloridexplorer.conf';
	$specialist = 'Burckhardt Daniel';
	$scrutinydate = '15/01/2015';
	$explorer = 'http://hemiptera.infosyslab.fr/cgi-bin/coleorrhyncha.pl';
	$order = 'Hemiptera';
	$suborder = 'Coleorrhyncha';
	$superfamily = '';
	$srcdir .= "/pelorids";
}
elsif ($base eq 'cipa') {
	$config_file = '/etc/flow/cipaexplorer.conf';
	$specialist = 'CIPA group';
	$scrutinydate = '16/09/2011';
	$explorer = 'http://cipa.snv.jussieu.fr/';
	$order = 'Diptera';
	$suborder = 'Nematocera';
	$superfamily = 'Psychodoidea';
	$srcdir .= "/cipa";
}
elsif ($base eq 'aleyrodidae') { 
	$config_file = '/etc/flow/aleurodsexplorer.conf';
	$specialist = 'Martin Jon H.';
	$scrutinydate = '15/05/2014';
	$explorer = 'http://www.hemiptera-databases.com/whiteflies';
	$order = 'Hemiptera';
	$suborder = 'Sternorrhyncha';
	$superfamily = 'Aleyrodoidea';
	$srcdir .= "/aleyrodidae";
}
elsif ($base eq 'tingidae') { 
	$config_file = '/etc/flow/tingides.conf';
	$specialist = 'Guilbert Eric';
	$scrutinydate = '15/01/2015';
	$explorer = 'http://hemiptera-databases.com/tingidae';
	$order = 'Hemiptera';
	$suborder = 'Heteroptera';
	$superfamily = '';
	$srcdir .= "/tingidae";
}
elsif ($base eq 'tessaratomidae') { 
	$config_file = '/etc/flow/tessaratomidae.conf';
	$specialist = 'Magnien Philippe';
	$scrutinydate = '01/08/2013';
	$explorer = 'http://hemiptera.infosyslab.fr/tessaratomidae';
	$order = 'Hemiptera';
	$suborder = 'Heteroptera';
	$superfamily = 'Pentatomoidea';
	$srcdir .= "/tessaratomidae";
}
elsif ($base eq 'brentidae') { 
	$config_file = '/etc/flow/brentidae.conf';
	$specialist = 'Alessandra Sforzi & Luca Bartolozzi';
	$scrutinydate = '15/01/2015';
	$explorer = 'http://hemiptera.infosyslab.fr/brentidae';
	$order = 'Coleoptera';
	$suborder = 'Polyphaga';
	$superfamily = 'Curculionoidea';
	$srcdir .= "/brentidae";
}
else { print html_header() . "URL parameter db must be one of (flow, cool, psyllist, etc...)" . p . "example: " . url() . "?db=flow" . br . html_footer(); exit; }


# Gets config
################################################################

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
}
else {
	print html_header() . "No configuration file found" . html_footer(); exit;
}


# Main
################################################################
if (param('TaxonomicCoverage') or $local) {
	$|++;	
	print 	html_header();
	#print	join(br, map { "$_ = ".param($_) } param()). br;

	if ( my $dbc = db_connection($config) ) { # connection
		$dbc->{RaiseError} = 1; #TODO: enhance error message...
		
		my ($kingdom, $phylum, $class);
		$kingdom = 'Eukarya';
		$phylum = 'Arthropoda';
		$class = 'Hexapoda';
		
		my $msg;
		my $distribfile = 'Distribution.csv';
		my $reffile = 'NameReferencesLinks.csv';
		my $file = 'AcceptedSpecies.csv';
		my $infrafile = 'AcceptedInfraSpecificTaxa.csv';
		my $comfile = 'CommonNames.csv';
		
		my %rfnmdone;
								
		if ( open(VALNAMES, '>', $srcdir."/".$file) and open(NAMESREF, '>', $srcdir."/".$reffile) and open(DISTRIB, '>', $srcdir."/".$distribfile) and open(SUBSPC, '>', $srcdir."/".$infrafile) and open(COMMONS, '>', $srcdir."/".$comfile) ) {
		
			my $status = 'Accepted name';
			my $GSDstatus;
			
			my ( $taxid, $nameid, $family, $subgenus, $genus, $species, $newcomb, $authors, $pubid, $fossil, $rang, $subspecies, $parentID );
			my $sth = $dbc->prepare( "SELECT t.index, sp.index, sp.orthographe, sp.parentheses, nc.autorite, nc.ref_publication_princeps, sp.fossil, r.en
							FROM taxons AS t 
							LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
							LEFT JOIN noms AS sp ON txn.ref_nom = sp.index
							LEFT JOIN noms_complets AS nc ON sp.index = nc.index
							LEFT JOIN rangs AS r ON t.ref_rang = r.index
							LEFT JOIN statuts AS s ON txn.ref_statut = s.index
							WHERE (r.en = 'species' OR r.en = 'subspecies')
							AND s.en = 'valid'
							ORDER BY r.en, t.index;");
									
			$sth->execute() or die "Can't execute the accepted names request";
			$sth->bind_columns( \( $taxid, $nameid, $species, $newcomb, $authors, $pubid, $fossil, $rang ) );
			print "Accepted name request done<br>";
			
			print VALNAMES <<E0;
"AcceptedTaxonID","Kingdom","Phylum","Class","Order","Superfamily","Family","Genus","SubGenusName","Species","AuthorString","GSDNameStatus","Sp2000NameStatus","IsExtinct","HasPreHolocene","HasModern","LifeZone","AdditionalData","LTSSpecialist","LTSDate","SpeciesURL","GSDTaxonGUI","GSDNameGUI"
E0
			print SUBSPC <<E1;
"AcceptedTaxonID","ParentSpeciesID","InfraSpeciesEpithet","InfraSpeciesAuthorString","InfraSpeciesMarker","GSDNameStatus","Sp2000NameStatus","IsExtinct","HasPreHolocene","HasModern","LifeZone","AdditionalData","LTSSpecialist","LTSDate","InfraSpeciesURL","GSDTaxonGUI","GSDNameGUI"
E1
			print NAMESREF <<E2;
"ID","Reference Type","ReferenceID"
E2
			print DISTRIB <<E3;
"AcceptedTaxonID","DistributionElement","StandardInUse","DistributionStatus"
E3
			print COMMONS <<E4;
"AcceptedTaxonID","CommonName","TransliteratedName","Country","Area","Language","ReferenceID"
E4
			while ( $sth->fetch()){
				
				if ($rang eq 'subspecies') {
					
					$subspecies = $species;
					
					my $sth0 = $dbc->prepare("SELECT parent_taxon_id((SELECT ref_taxon_parent FROM taxons WHERE index = $taxid), 'species');");
					$sth0->execute() or die "can't execute the species request";
					$sth0->bind_columns( \( $parentID ) );
					$sth0->fetch();
				}
				
				my $sth2 = $dbc->prepare("SELECT parent_taxon_name((SELECT ref_taxon_parent FROM taxons WHERE index = $taxid), 'subgenus');");
				$sth2->execute() or die "can't execute the subgenus request";
				$sth2->bind_columns( \( $subgenus ) );
				$sth2->fetch();
				if ($subgenus) { 
					my $temp;
					($temp,$subgenus) = split(/ /, $subgenus, 2);
					$subgenus = substr($subgenus,1,-1);
				}
			
				my $sth3 = $dbc->prepare("SELECT parent_taxon_name((SELECT ref_taxon_parent FROM taxons WHERE index = $taxid), 'genus');");
				$sth3->execute() or die "can't execute the genus request";
				$sth3->bind_columns( \( $genus ) );
				$sth3->fetch();
				
				my $sth4 = $dbc->prepare("SELECT parent_taxon_name((SELECT ref_taxon_parent FROM taxons WHERE index = $taxid), 'family');");
				$sth4->execute() or die "can't execute the genus request";
				$sth4->bind_columns( \( $family ) );
				$sth4->fetch();
								
				my $modern;
				if ($fossil) { $fossil = 1; $modern = 0; } else { $fossil = 0; $modern = 1; }
				
				if ($newcomb == 1) { $GSDstatus = 'new combination, valid: Yes' } 
				elsif ($newcomb == 0) { $GSDstatus = 'original combination, valid: Yes' } 
				else { die $newcomb }
				
				my $urlplus;
				
				if ($base eq 'flow') { $urlplus = "&page=explorer&db=flow" }
				
				if ($rang eq 'subspecies') {
					print SUBSPC <<E5;
$taxid,$parentID,"$subspecies","$authors",,"$GSDstatus","$status",0,$fossil,$modern,"terrestrial",,"$specialist","$scrutinydate",$explorer?lang=en&card=name&id=$nameid$urlplus",,
E5
				}
				elsif ($rang eq 'species') {
					print VALNAMES <<E6;
$taxid,"$kingdom","$phylum","$class","$order","$superfamily","$family","$genus","$subgenus","$species","$authors","$GSDstatus","$status",0,$fossil,$modern,"terrestrial",,"$specialist","$scrutinydate","$explorer?lang=en&card=name&id=$nameid$urlplus",,
E6
				}
				else { die $rang }
				
				if ($pubid and !exists $rfnmdone{$taxid.'/'.$pubid}) { 
					print NAMESREF <<E7;
$taxid,"TaxAccRef",$pubid
E7
					$rfnmdone{$taxid.'/'.$pubid} = 1;
				}
				
				my $distrib = request_tab("SELECT distinct p.tdwg FROM pays AS p LEFT JOIN taxons_x_pays AS txp ON txp.ref_pays = p.index WHERE txp.ref_taxon = $taxid", $dbc, 1);

				foreach (@{$distrib}) {
					print DISTRIB <<E8;
$taxid,"$_","TDWG Level 4 code","native"
E8
				}
				
				my $req = "select nom, en, tdwg, langage, ref_pub from taxons_x_vernaculaires as txn left join noms_vernaculaires as n on n.index = txn.ref_vernaculaire left join langages as l on l.index = n.ref_langage left join pays as p on p.index = n.ref_pays where txn.ref_taxon = $taxid;";
				
				my $commons = request_tab($req, $dbc, 2);
								
				foreach (@{$commons}) {
					print COMMONS <<E9;
$taxid,"$_->[0]",,"$_->[1]","$_->[2]","$_->[3]",$_->[4]
E9
				}
				print ".";
			}
			print "<br>";
			
			close(VALNAMES);
			close(SUBSPC);
			close(DISTRIB);
			close(COMMONS);
			
			$msg .= $srcdir."/".$file." Updated".br; 
			$msg .= $srcdir."/".$infrafile." Updated".br; 
			$msg .= $srcdir."/".$distribfile." Updated".br; 
			$msg .= $srcdir."/".$comfile." Updated".br; 
			print "$msg<br>";
		}
		else {
			print "Can't open files" . html_footer(); exit;
		}
				
		$file = 'Synonyms.csv';
		
		if ( open(SYNS, '>', $srcdir."/".$file) ) {
		
			my $GSDstatus;
			
			my ( $taxid, $nameid, $name, $genus, $subgenus, $species, $subspecies, $newcomb, $authors, $pubid, $status, $denonid, $parent, $rang, $sspauthors );
			my $sth = $dbc->prepare( "SELECT t.index, sp.index, sp.orthographe, sp.parentheses, nc.autorite, nc.ref_publication_princeps, s.en, txn.ref_publication_denonciation, sp.ref_nom_parent
							FROM taxons AS t 
							LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
							LEFT JOIN noms AS sp ON txn.ref_nom = sp.index
							LEFT JOIN noms_complets AS nc ON sp.index = nc.index
							LEFT JOIN rangs AS r ON t.ref_rang = r.index
							LEFT JOIN statuts AS s ON txn.ref_statut = s.index
							WHERE r.en = 'species'
							AND s.index not in (1, 8, 10, 14, 17, 18, 20, 21, 22);");
									
			$sth->execute( ) or die "Can't execute the synonyms request";
			$sth->bind_columns( \( $taxid, $nameid, $name, $newcomb, $authors, $pubid, $status, $denonid, $parent ) ) or die "can't bind synonym request";
			print "Synonyms request done<br>";

			print SYNS <<E10;
"ID","AcceptedTaxonID","Genus","SubGenusName","Species","AuthorString","InfraSpecies","InfraSpecificMarker","InfraSpecificAuthorString","GSDNameStatus","Sp2000NameStatus","GSDNameGUI"
E10
			my %syndone;
			while ( $sth->fetch() ){
				
				while ($parent) {
					my $nom;
					my $tmp = request_tab("SELECT n.ref_nom_parent, n.orthographe, r.en FROM noms AS n LEFT JOIN rangs AS r ON r.index = n.ref_rang WHERE n.index = $parent", $dbc, 2);
					($parent, $nom, $rang) = ($tmp->[0][0],$tmp->[0][1],$tmp->[0][2]);
					if ($rang eq 'species') { $species = $nom; $subspecies = $name; $sspauthors = $authors; $authors = undef; }
					elsif ($rang eq 'subgenus') { $subgenus = $nom; unless ($species) { $species = $name } }
					elsif ($rang eq 'genus') { $genus = $nom; unless ($species) { $species = $name } }
				}
				
				if ($newcomb == 1) { $GSDstatus = 'new combination, valid: No' } 
				elsif ($newcomb == 0) { $GSDstatus = 'original combination, valid: No' }
				else { die $newcomb }
								
				if ($status eq 'nomen praeoccupatum' or $status eq 'misidentification' or $status eq 'previous identification') { $status = 'Ambiguous Synonym' } else { $status = 'Unambiguous Synonym' }
				
				unless (exists $syndone{"$nameid,$taxid"}) {
					$syndone{"$nameid,$taxid"} = 1;
					print SYNS <<E11;
$nameid,$taxid,"$genus","$subgenus","$species","$authors","$subspecies",,"$sspauthors","$GSDstatus","$status",
E11
				}
				($genus,$subgenus,$species,$authors,$subspecies,$sspauthors) = (undef,undef,undef,undef,undef,undef);
				
				if ($pubid and !exists $rfnmdone{$taxid.'/'.$pubid}) { 
					print NAMESREF <<E12;
$taxid,"NomRef",$pubid
E12
					$rfnmdone{$taxid.'/'.$pubid} = 1;
				}
				if ($denonid and !exists $rfnmdone{$taxid.'/'.$denonid}) { 
					print NAMESREF <<E13;
$taxid,"NomRef",$denonid
E13
					$rfnmdone{$taxid.'/'.$denonid} = 1;
				}
				print ".";
			}
			print "<br>";
			
			close(SYNS);
			
			print $srcdir."/".$file." Updated".br; 
		}
		else {
			print "Can't open ". $srcdir."/".$file . html_footer(); exit;
		}
		
		close(NAMESREF);
		
		$file = 'References.csv';
		
		if ( open(REFS, '>', $srcdir."/".$file) ) {
			
			my ( $pubid, $authors, $year, $title, $origin );
			
			my $sth = $dbc->prepare( "SELECT index FROM publications");
			
			$sth->execute( ) or die "Can't execute the synonyms request";
			
			$sth->bind_columns( \( $pubid ) );
			
			print REFS <<E14;
"ReferenceID","Authors","Year","Title","Details"
E14

			while ( $sth->fetch() ){
				($authors, $year, $title, $origin) = pub_formating(get_pub_params($dbc, $pubid), 'text');
				print REFS <<E15;
$pubid,"$authors",$year,"$title","$origin"
E15
			}
			
			close(REFS);
			
			print $srcdir."/".$file." Updated".br;		
		}
		else {
			print "Can't open ". $srcdir."/".$file . html_footer(); exit;
		}
		
		if (param('TaxonomicCoverage')) {
			
			$file = 'SourceDatabase.csv';
			
			if ( open(SDB, '>', $srcdir."/".$file) ) {
				
				print SDB <<E16;
"DatabaseFullName","DatabaseShortName","DatabaseVersion","ReleaseDate","AuthorsEditors","TaxonomicCoverage","GroupNameInEnglish","Abstract","Organisation","HomeURL","Coverage","Completeness","Confidence","LogoFileName","ContactPerson"
E16
				print SDB '"'.param('DatabaseFullName').'","'.param('DatabaseShortName').'","'.param('DatabaseVersion').'","'.param('ReleaseDate').'","'.param('AuthorsEditors').'","'.param('TaxonomicCoverage').'",,"'.param('Abstract').'","'.param('Organisation').'","'.param('HomeURL').'","Global",'.param('Completeness').','.param('Confidence').',"'.param('LogoFileName').'","'.param('ContactPerson').'"';

				close(SDB);
				
				print $srcdir."/".$file." Updated".br;		
			}
			else {
				print "Can't open ". $srcdir."/".$file . html_footer(); exit;
			}
		}
			
		print	html_footer();
			
		$dbc->disconnect; # disconnection
		
		exit;
	}
	else { 
		print "Connection to $base failed" . html_footer(); exit;
	}
}
else {
	my @defaults;	
	my @fields;
	my $test;
	
	my $file = 'SourceDatabase.csv';

	my $line = 1;
	if ( open(DBS, $srcdir."/".$file) ) {
		while (<DBS>) {
			#$test .= $_ . "\n";
			chomp;                 # no newline
			s/^\s+//;              # no leading white
			s/\s+$//;              # no trailing white
			s/,,/,"",/g;
			s/,([0-9]+)/,"\1"/g;
			#$test .= $_ . "\n";
			next unless length;    # anything left?
			if ($line == 1) { @fields = split(/","/, substr($_,1,-1)); }
			elsif ($line == 2) { @defaults = split(/","/, substr($_,1,-1)); }
			$line++;
		}
		close(DBS);
	}
	else {
		print html_header() . "No Source Database file found" . html_footer(); exit;
	}
	
	$line = 0;
	my @rows;
	foreach (@fields) {
		push(@rows, Tr(td({-align=>'left', -style=>'padding-right: 10px; padding-bottom: 25px;'},span({-class=>'textLarge'},span({-class=>'textNavy'},b($fields[$line])))),td({-align=>'left', -style=>'padding-bottom: 25px;'}, textfield(-class=>'phantomTextField', -name=>"$fields[$line]", -style=>'width: 600px;', -default=>$defaults[$line]))));
		$line++;
	}
	
	print html_header().
		
	$test.
	
	#join(br, map { "$_ = ".param($_) } param()). br.
						
	start_form(-name=>'dbsource', -method=>'post',-action=>'').
		
	div(
		table({-border=>0}, @rows, Tr(td( div( {-onClick=>"dbsource.action='".url()."?db=$base'; dbsource.submit();"}, img({-border=>0, -src=>'/Editor/ok.png', -name=>"Ok"}) ) )
		))
	).
					
	end_form().
	
	html_footer();
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
		print html_header('Error'),
			div( { -id=>'navigation' }, '' ),
			div( { -id=>'content' },
			h1( { -class=>'warning' }, "Database connection error"),
			pre($error_msg),p,
			"please contact the ",
			a({href=>"mailto:$webmaster"},"webmaster"),
			),
			html_footer();
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
		else { die "Could'nt execute sql request: $DBI::errstr\n--$req--\n" } # Could'nt execute sql request
	} else { die "Could'nt prepare sql request: $DBI::errstr\n--$req--\n" } # Could'nt prepare sql request

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
	my ($title) = @_;
	
	my $html = header({-Type=>'text/html', -Charset=>'UTF-8'});
	$html .= start_html(-title  =>$title,
			-author =>'anta@mnhn.fr',
			-base   =>'true',
			-head   =>meta({-http_equiv => 'Content-Type',
					-content    => 'text/html; charset=utf8'}),
			-meta   =>{'description'=>'catalogue of life'},
			-script=>{-language=>'JAVASCRIPT',-src=>'/explorerdocs/pngfixall.js'},
			-bgcolor => 'ivory',
			-text => 'navy'
		);
	$html .=  h3("$base Catalogue of Life") . p;
	return ($html);
}

# Builds a string witch contains html footer
############################################################################################
sub html_footer {
	my $html = h5( time2str("%d/%m/%Y-%X\n", time) ); # Prints date
	$html = div( { -id=>'footer' }, $html );
	$html .= end_html();
	return ($html);
}


# Get all necessary informations of a publication from his index to put it in a hash.
############################################################################################
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
		if (my $annee = $pub->{$index}->{'annee'}) { push(@strelmt,"$annee"); } else { push(@strelmt," - "); }
		if (my $titre = $pub->{$index}->{'titre'}) { push(@strelmt,"$titre"); } else { push(@strelmt,"Title unknown"); }
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
		if (my $annee = $pub->{$index}->{'annee'}) { push(@strelmt,"$annee"); } else { push(@strelmt," - "); }
		if (my $titre = $pub->{$index}->{'titre'}) { 	if ($format eq 'html') { push(@strelmt,i("$titre")); } else { push(@strelmt,"$titre"); } } 
		else { if ($format eq 'html') { push(@strelmt,i("Title unknown")); } else { push(@strelmt,"Title unknown"); } }
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
		if (my $annee = $pub->{$index}->{'annee'}) { push(@strelmt,"$annee"); } else { push(@strelmt," - "); }
		if (my $titre = $pub->{$index}->{'titre'}) { push(@strelmt,"$titre"); } else { push(@strelmt,"Title unknown"); }
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
				
				$book_author_str = join(', ',@authors_livre)." & $pub->{$index}->{'auteurslivre'}->{$nb_authors_livre}->{'nom'} $pub->{$index}->{'auteurslivre'}->{$nb_authors_livre}->{'prenom'}";
			
			} else {
				$book_author_str = "$pub->{$index}->{'auteurslivre'}->{$nb_authors_livre}->{'nom'} $pub->{$index}->{'auteurslivre'}->{$nb_authors_livre}->{'prenom'}";
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
			
			my $dbc = db_connection($config);
									
			push(@strelmt, join(' ', pub_formating(get_pub_params($dbc, $pub->{$index}->{'indexlivre'}), $format))); 
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
		if (my $annee = $pub->{$index}->{'annee'}) { push(@strelmt,"$annee"); } else { push(@strelmt," - "); }
		if (my $titre = $pub->{$index}->{'titre'}) { 	if ($format eq 'html') { push(@strelmt,i("$titre")); } else { push(@strelmt,"$titre"); } }
		else { if ($format eq 'html') { push(@strelmt,i("Title unknown")); } else { push(@strelmt,"Title unknown"); } }
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
	return (shift @strelmt, shift @strelmt, shift @strelmt, join(' ', @strelmt));	
}
