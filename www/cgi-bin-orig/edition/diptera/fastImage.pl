#!/usr/bin/perl
BEGIN {push @INC, '/var/www/cgi-bin/edition/diptera/'} 
use strict;
use warnings;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use DBCommands qw (get_connection_params db_connection request_tab request_hash);
use Conf qw ($conf_file $css $jscript_for_hidden $dblabel $cross_tables $single_tables html_header html_footer arg_persist $maintitle);
use File::Copy "mv";
use Sys::Hostname;
use POSIX qw(strftime);

my $config = get_connection_params($conf_file);
my $dbc = db_connection($config, 'EXPLORER');

my $JSCRIPT = "";
my $title = "Mass image uploader";
my $db = url_param('db') || param('db');
my $action = url_param('action') || param('action');

#my $path = "/var/www/html/Documents";
my $path = "/var/www/html/Documents";

my $subdir = "/web/direct";

my $trgtdir = "/web/enligne";

my $datestring = strftime "%y%m%d%H%M%S", localtime;

my %directories = (
	"flow" 		=> "/flowfotos",
	"cool" 		=> "/coolfotos",
	"psyllist" 	=> "/psylfotos",
	"aleurodes" 	=> "/aleurodfotos"
);

my $separator = "<span style='color: crimson;'>##</span>";

my %headerHash = (
	titre => $title,
	css => $css,
	jscript => $JSCRIPT,
	onLoad => ""
);


my $content;
my $msg;

if ($db) {
		my $host = url(-base=>1);	
		my $dir = $directories{$db};
		
		my $howto = "
		Put images on the server in the source directory.<br>
		Source directory : ".$path.$dir.$subdir."<br><br>
		Make sure the images names respect one of the following syntaxes:<br><br>
		scientific name".$separator."type".$separator."image description".$separator."number".$separator.".extension<br>
		scientific name".$separator."collection".$separator."image description".$separator."number".$separator.".extension<br>
		scientific name".$separator."nature".$separator."image description".$separator."number".$separator.".extension<br><br>
		
		the \"number\" field is mandatory and must be incremented for each image with the same \"scientific name\" as shown in examples.
		
		examples:<br><br>
		- with description:<br><br>
		Agalmatium bilobum##nature##Female##1##.jpg<br>
		Agalmatium bilobum##nature##Male##2##.jpg<br>
		Agalmatium bilobum##collection##Male##3##.jpg<br><br>
		- without description:<br><br>
		Agalmatium bilobum##nature####1##.jpg<br>
		Agalmatium bilobum##nature####2##.jpg<br>
		Agalmatium bilobum##type####3##.jpg<br><br>
		Images will be inserted in database and moved to the target directory.<br>
		Target directory : ".$path.$dir.$trgtdir."<br><br>
		click on Start button to upload images.";
		
		if ($action eq 'Start') {
		
			my $i = 0;
			opendir(DIR, $path.$dir.$subdir) or die $!;
			while (my $file = readdir(DIR)) {
				
				next if ($file =~ m/^\./);
				my ($name, $type, $text, $nb, $ext) = split("##", $file);
				
				if ($name and $type and $ext and $nb) {
					
					my $dstr = $datestring + $nb;
					#$content .= "($name, $type, $text, $ext, $nb, $dstr)<br>";
					
					my $req = "SELECT index, orthographe || ' ' || autorite FROM noms_complets WHERE orthographe = '$name' AND index IN (SELECT ref_nom FROM taxons_x_noms) LIMIT 1;";
					
					if (scalar(@{request_tab($req, $dbc, 2)})) {
						
						my ($nameID, $spelling) = @{@{request_tab($req, $dbc, 2)}[0]};
						
						$req = "SELECT ref_taxon FROM taxons_x_noms WHERE ref_nom = $nameID LIMIT 1;";
					
						my ($taxID) = @{request_tab($req, $dbc, 1)}[0];
						
						if ($taxID) {
							
							my $newname = $name."_".$type."_".$dstr.$ext;
							#$content .= "$newname<br>";
							
							if ($type eq 'type') {
								$req = "BEGIN; INSERT INTO images (url) VALUES ('".$host.$dir.$trgtdir."/".$newname."'); INSERT INTO noms_x_images (ref_nom, commentaire, ref_image) VALUES ($nameID, '$text', (SELECT max(index) FROM images)); END;";
							}
							else {
								$req = "BEGIN; INSERT INTO images (url) VALUES ('".$host.$dir.$trgtdir."/".$newname."'); INSERT INTO taxons_x_images (ref_taxon, ref_nom, commentaire, type, ref_image) VALUES ($taxID, $nameID, '$text', '$type', (SELECT max(index) FROM images)); END;";
							}
							if ( my $sth = $dbc->prepare($req) ){
								if ( $sth->execute() ) {
									$sth->finish();
									$content .= "$file TREATED<br>";
									mv($path.$dir.$subdir."/".$file,$path.$dir.$trgtdir."/".$newname) or die $!;
								} 
								else { 
									die "Execute error: $req with ".$dbc->errstr; 
								} 
							} else { die "Prepare error: $req with ".$dbc->errstr; }
						}
						else {
							$content .= "<span style='color: red;'>NO TAXON FOUND for name $name in ".uc($db)."<br></span>";
						}
					}
					else {
						$content .= "<span style='color: red;'>name $name NOT FOUND in ".uc($db)."<br></span>";
					}
				}
				else {
					$content .= "<span style='color: red;'>$file PARSING FAILED<br></span>";
				}
				$i++;
			}                                                                  
			$content .= br. br. a({-href=>'fastImage.pl?db=flow', -style=>'text-decoration: none; color: darkblue;'},"Back");
			closedir(DIR);
	
			#my $req = "";
			#my $res = request_tab($req, $dbc, 2);
			#
			#my $breq = "BEGIN;";
			#foreach (@{$res}) {
			#	$breq .= "";
			#}
			#$breq .= "COMMIT;";
			#
			##if ( my $sth = $dbc->prepare($breq) ){ if ( $sth->execute() ) { $sth->finish(); } else { die "Execute error: $breq with ".$dbc->errstr; } } else { die "Prepare error: $breq with ".$dbc->errstr; }
			#
			#$content = 	img({-border=>0, -src=>'/dbtntDocs/done.png', -name=>"done" , -alt=>"DONE"}).
			#		br.br.
			#		span({-style=>"color: darkgreen;"},"Image(s) inserted in $db").
			#		br.br.
			#		a({-href=>"fastImage.pl?db=$db", -style=>'text-decoration: none;'},"Insert more images");
	}
	elsif ($action eq 'goGer') {
		
		my $regexp = "^(([^\n() ]+ +[^\n() ]+)|([^\n() ]+ +\\([^\n() ]+\\) +[^\n() ]+)) +[^\n]+.jpg";
		my $dir = $directories{$db};
		
		my $host = url(-base=>1);
		$content .= "$host<br>";
		
		my $i = 0;
		opendir(DIR, $path.$dir.$subdir) or die $!;
		while (my $file = readdir(DIR) and $i<100) {
			
			next if ($file =~ m/^\./);
						
			if ($file =~ m/$regexp/) {
				
				my $req = "SELECT index, orthographe || ' ' || autorite FROM noms_complets WHERE orthographe = '$1';";
				
				my ($nameID, $spelling) = @{@{request_tab($req, $dbc, 2)}[0]};
				
				if ($nameID) {
				
					$req = "SELECT ref_taxon FROM taxons_x_noms WHERE ref_nom = $nameID;";
				
					my ($taxID) = @{request_tab($req, $dbc, 1)}[0];
					
					if ($taxID) {
						
						$req = "BEGIN; INSERT INTO images (url) VALUES ('".$host.$dir.$trgtdir."/".$file."'); INSERT INTO taxons_x_images (ref_taxon, ref_nom, ref_image) VALUES ($taxID, $nameID, (SELECT max(index) FROM images)); END;";
						
						if ( my $sth = $dbc->prepare($req) ){
							if ( $sth->execute() ) {
								$sth->finish();
								$content .= "$file TREATED<br>";
								mv($path.$dir.$subdir."/".$file,$path.$dir.$trgtdir."/".$file) or die $!;
							} 
							else { 
								die "Execute error: $req with ".$dbc->errstr; 
							} 
						} else { die "Prepare error: $req with ".$dbc->errstr; }
					}
					else {
						$content .= "<span style='color: red;'>NO TAXON FOUND for name $1 in ".uc($db)."<br>";
					}
				}
				else {
					$content .= "<span style='color: red;'>name $1 NOT FOUND in ".uc($db)."<br>";
				}
			}
			else {
				$content .= "<span style='color: red;'>$file PARSING FAILED<br>";
			}
			$i++;
		}
		
		closedir(DIR);
	}
	else {
		$content .= 	start_form(-name=>'mainForm', -method=>'post',-action=>'fastImage.pl').
				$title. br.br.
				$howto. br.br.
				$msg.
				arg_persist().
				submit('action','Start').
				end_form();
	}
}
else {
	$content = "ERROR : url syntax fastImage.pl?db=mydb WHERE mydb in (flow, cool, psyllist, aleurodes)";
}

print 	html_header(\%headerHash),

	#join(br, map { "$_ = ".param($_) } param()).
	
	$maintitle,
	div({-class=>"wcenter", -style=>'width: 1300px;'},
		$content
	),
	
	html_footer();


$dbc->disconnect();
exit;
