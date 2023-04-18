#!/usr/bin/perl 

use strict;
use CGI qw (-no_xhtml :standard);
use CGI::Carp qw (fatalsToBrowser warningsToBrowser);

#use TaxalifeFonc qw (get_connection_params db_connection request_tab request_hash request_row getTaxonomists formatName getNothonyms getEunymsFromValid formatNamesSpecies getSpeciesTyp searchLastValidity getMorphonyms getHomonyms getArcheo getPeriodValiditymorpho getLapsValidityEunym getUsageFromUsage getMorphonym);		

# modif sauvenay lors de la migration sur rameau
# seules les fonctions propres a TaxalifeFonc sont activées
# les fonctions issues de DBCommands sont directement appelées dans DBCommands, avec read_lang en plus
use TaxalifeFonc qw (getTaxonomists formatName getNothonyms getEunymsFromValid formatNamesSpecies getSpeciesTyp searchLastValidity getMorphonyms getHomonyms getArcheo getPeriodValiditymorpho getLapsValidityEunym getUsageFromUsage getMorphonym);		
use DBCommands qw (get_connection_params db_connection request_tab request_hash request_row read_lang);


my $dbconnect = db_connection(get_connection_params("/etc/flow/nomendb.conf"));

# traductions
#my $dbc = db_connection(get_connection_params('/etc/flow/flowexplorer.conf'));
#my $traduction = request_hash("SELECT id, fr, en FROM traductions;", $dbc, "index");
# argument lang dans l'url valeurs: en, fr, sp
my $xlang;
if (url_param('lang')) { $xlang = url_param('lang'); } else { $xlang = 'en'; }

my $traduction = read_lang(get_connection_params('/etc/flow/flowexplorer.conf'), $xlang);
									
# prend en parametres l'index du genre etudie ($gid)
my $gid;
if (url_param('genus')) { $gid = url_param('genus'); }
else { $gid = param('genus_list'); }

my $abst;
if (url_param('abst')) { $abst = url_param('abst') } else { $abst = param('abstract') }
my $fullh;
if (url_param('full')) { $fullh = url_param('full') } else { $fullh = param('fullhistory') }


######################################### INTRO #########################################################
 
# recherche la famille d'un genre avec l'année princeps 
# recherche le statut taxonomique du nom de genre 
my $infotaxon = request_hash ("	SELECT nf.index, nf.orthographe as famille, nf.annee_princeps as annee_famille, 
								txn.usage, n.orthographe as genre , n.annee_princeps as annee_genre				
								FROM noms AS n																						
								LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = n.index
								LEFT JOIN taxons AS t ON txn.ref_taxon = t.index
								LEFT JOIN taxons_x_noms AS txn2 ON t.ref_taxon_parent = txn2.ref_taxon
								LEFT JOIN noms AS nf ON nf.index = txn2.ref_nom
								WHERE n.index= '$gid' AND txn2.usage = 'valide'
								AND txn.usage NOT IN ('orthochresonyme', 'heterochresonyme');",$dbconnect,"index");
my $genusintro;
my $nothoabstract;
my $eunymabstract;
my $title;
my $caption;
my $genuslife;
my $genusdate;

foreach my $id (keys %{$infotaxon}) { 
	my $aut = getTaxonomists ($infotaxon->{$id}{index},'auteurs');# auteurs de la famille
	my $author = getTaxonomists ($gid,'auteurs');  # auteurs du genre
	$title = "$infotaxon->{$id}{'genre'} $author, $infotaxon->{$id}{'annee_genre'}";
	$caption = i($infotaxon->{$id}{'genre'})." $author, $infotaxon->{$id}{'annee_genre'}"; 	

	$genuslife = br.span ({-style=>'font-size: large; font-weight: bold; font-family: arial; padding-left: 20px;' }, "$traduction->{'taxahist'}->{$xlang} $caption").br.br;
	$genusdate ="$infotaxon->{$id}{'annee_genre'}";

	# famille du genre et genre recherché avec son statut taxonomique
	$genusintro .= "$traduction->{'taxastatutact'}->{$xlang}".br."$traduction->{'taxafamil'}->{$xlang} ".span ({-class=> 'majuscule'},"$infotaxon->{$id}{'famille'}")." $aut, $infotaxon->{$id}{'annee_famille'}".br;
	
	$genusintro .= i($infotaxon->{$id}{'genre'})." $author, $infotaxon->{$id}{'annee_genre'} : ";	
	if ( $infotaxon->{$id}{'usage'} eq 'valide') {
		 $genusintro .= b($traduction->{'taxaval'}->{$xlang}).br;
	}
	elsif ( $infotaxon->{$id}{'usage'} eq 'valide seniorise') {
		$genusintro .= b($traduction->{'taxasenval'}->{$xlang}).br;
	}
	elsif ( $infotaxon->{$id}{'usage'} eq 'synonyme subjectif') {
		$genusintro .= b($traduction->{'taxasubsyn'}->{$xlang}).br;
	}
	else {
		$genusintro .= b($traduction->{'taxajunsubsyn'}->{$xlang}).br;
	}	
	
	
	if ( $infotaxon->{$id}{'usage'} =~ m/valide/g)  {
		
		my $synsub= "$traduction->{'taxasubsyn'}->{$xlang}";
		my $infosynsub = getUsageFromUsage ('synonyme subjectif',$infotaxon->{$id}{'usage'}, $gid);		
		my $junior;
		my $synsubjunior;
		
		if ($infotaxon->{$id}{'usage'} =~ m/seniorise/g) {
			$synsubjunior = "$traduction->{'taxajunsubsyn'}->{$xlang}";
			$junior = getUsageFromUsage ('synonyme subjectif juniorise','valide seniorise', $gid);
		}
		
		if ($junior) {
			my ($id) = keys(%{$junior});
			$genusintro .= div ({-style=>'position:relative;left:20px'} ,formatName($junior->{$id}). " : $synsubjunior");
		}
		
		foreach my $id (keys %{$infosynsub}) {
			$genusintro .= div ({-style=>'position:relative;left:20px'} ,formatName($infosynsub->{$id}). " : $synsub");
		}
	}
	
	elsif ($infotaxon->{$id}{'usage'} =~ m/synonyme/g)  {
			
		my $infovalid;
		my $infovalsenior;
		my $valid = 'valide';
		my $valsenior = 'valide seniorise';
		my $synsub = "$traduction->{'taxasubsyn'}->{$xlang}";
		my $synsubjunior = "$traduction->{'taxajunsubsyn'}->{$xlang}";
		
		
		if ($infotaxon->{$id}{'usage'} =~ m/juniorise/g) {
			$infovalid = getUsageFromUsage ('valide seniorise','synonyme subjectif juniorise', $gid);
			
			my ($usagid) = (keys %{$infovalid});
			$genusintro .= "$synsubjunior de ".formatName($infovalid->{$usagid}). br; 
				
		}	
		else {
			$infovalid = getUsageFromUsage ('valide','synonyme subjectif', $gid);
			$infovalsenior = getUsageFromUsage ('valide seniorise','synonyme subjectif', $gid);
			

			foreach my $id (keys %{$infovalid}) {
				$genusintro .= "$synsub $traduction->{'taxaof'}->{$xlang} ".formatName($infovalid->{$id}). br; 
			}
			
			foreach my $id (keys %{$infovalsenior}) {
				$genusintro .= "$synsub $traduction->{'taxaof'}->{$xlang} ".formatName($infovalsenior->{$id}).br;
				 
			}
			
		}

	}
}	

# espece-type du genre etudie
my $speciestyp = getSpeciesTyp($gid);
my ($speid) =  (keys %{$speciestyp});


if (scalar (keys(%{$speciestyp})))  {
	$genusintro .= " $traduction->{'taxatype'}->{$xlang} : ".formatNamesSpecies($speciestyp->{$speid}). br.br;
}
else {$genusintro .= br;} # pour saut de ligne si pas d'espèce-type!!!!!!	


############################################### NOMS CORRECTS #############################################		
					
my $eunyms = getEunymsFromValid($gid); # dico des eunymes
my $dureeajout; # durée commulee de validite de tous les eunymes
my $lastvaleunym = searchLastValidity($eunyms);
my $duree; # duree de validite
my $eunymtext;
my $status;

if (scalar (keys(%{$eunyms})))  {
	if ($fullh) {
		$eunymtext = span ({-class=> 'text'},"$traduction->{'taxavalspelife'}->{$xlang} :").br.br;
	}
	else {
		$eunymtext = span ({-class=> 'text'},"$traduction->{'taxavalspelist'}->{$xlang} :").br.br;
	}
	
	my $i = 1;  # compteur pour calculer nb d'eunymes totaux
	my $orieunym = 0;
	my $eunymshistories;
	
	
		# sortie des eunymes par année princeps puis par ordre alpha
		foreach my $id  ( sort {$eunyms->{$a}{annee_princeps} <=> $eunyms->{$b}{annee_princeps}
		|| $eunyms->{$a}{espece} cmp $eunyms->{$b}{espece}} keys(%{$eunyms})) {
			
			if (($eunyms->{$id}{annee_princeps} == $genusdate && (!$eunyms->{$id}{parentheses})) || ($eunyms->{$id}{annee_validite} == $genusdate)) {
				$orieunym++;
			}	
			if ($fullh) {			
				my $allmorphos = getMorphonyms($eunyms->{$id}, 'all', 'disponible'); # recherche de tous les morphonymes
				$duree = getLapsValidityEunym ($eunyms->{$id});
				 
				
				my $k=1;# pour l'indentation des eunymes
				my @sortedcles = sort {$allmorphos->{$b}{annee_validite} <=> $allmorphos->{$a}{annee_validite}} (keys (%{$allmorphos}));			 
				
				foreach my $id (@sortedcles) {
				
					my $eunymhistory;
					
					if ($allmorphos->{$id}{erreur} =~ m/^$/) {
					
						$eunymhistory .= formatNamesSpecies($allmorphos->{$id});
										
						my @statut;
						my @synonymies;
						my @homonymies;
					
						my $homosprim = getHomonyms($allmorphos->{$id},'homonymie primaire', 'plus_recents');
						my $homossecon = getHomonyms($allmorphos->{$id},'homonymie secondaire','plus_recents');
						my $archeo =  getArcheo($allmorphos->{$id}, 'neonymie', 'plus_ancien');
						my $lastsyn = getArcheo($allmorphos->{$id}, 'nom de remplacement par synonymie', 'plus_ancien');
					
						my $nomennovum	= 	span ({-style=>'italic'}, " nomen novum ")." de";
						if ($archeo) { push(@statut,$nomennovum);push(@synonymies,$archeo) };
						if ($lastsyn) { push(@statut,'ancien synonyme subjectif de ');push(@synonymies,$lastsyn) };
					
						if ($homosprim) { 
							foreach my $id (keys %{$homosprim}) {
								push(@homonymies,formatNamesSpecies($homosprim->{$id}));
							 }
						}
						
						if ($homossecon) { 
							foreach my $id (keys %{$homossecon}) {
									push(@homonymies,formatNamesSpecies($homossecon->{$id}));
							 }
						} 			
						
						if (scalar (@homonymies) ) {
							
								$eunymhistory .= " [non ".join ('nec ', @homonymies)." ]";
						}
						
						if (scalar (@synonymies) ) {
								my $j=0;
								foreach my $type (@synonymies) {
									foreach my $id (keys %{$type}) {
										$eunymhistory .= " [ $statut[$j] ".formatNamesSpecies($type->{$id})."]";
								}
								$j++;
							}
						}
						
						if (scalar(@sortedcles) > 1) {
							if ($k == scalar(@sortedcles)) {
								$eunymhistory = span ({-style=>'position:relative; left:50px;'},$eunymhistory);
							}
							else {
								if ($k == 1) { $eunymhistory = "$i- $eunymhistory" }
								else { $eunymhistory = span ({-style=>'position:relative; left:30px;'},$eunymhistory); }
							}
							$k++;
						} else { $eunymhistory = "$i- $eunymhistory" }
					
						$eunymshistories .= $eunymhistory. br;
					}
	
				}
						
				$dureeajout += $duree ;
				$i++;
			
		}
		
		else {
				my $eunymhistory .= formatNamesSpecies($eunyms->{$id}).br;
				$eunymshistories .= "$i- $eunymhistory";
				$duree = getLapsValidityEunym ($eunyms->{$id});
				
				$dureeajout += $duree ;
				$i++;
			}
		}
	
	$eunymtext .= $eunymshistories.br;
		
	
	
	foreach my $id (keys %{$infotaxon}) {
		my $author = getTaxonomists ($gid,'auteurs');
		$status .= "$traduction->{'taxavalsince'}->{$xlang} $lastvaleunym".br;
	} 
	if ($orieunym!= 0) {
			$status .= "$traduction->{'taxaorispecies'}->{$xlang} $orieunym $traduction->{'taxaspecies'}->{$xlang}".br;
		}
	$eunymabstract .= "$traduction->{'taxanow'}->{$xlang} ". ($i-1)." $traduction->{'taxavalspe'}->{$xlang} ".br;
	if ($i != 0) {
		$eunymabstract .=  "$traduction->{'taxalifemean'}->{$xlang} : ". int ($dureeajout/($i-1))." $traduction->{'taxayears'}->{$xlang}".br;
	}
}

	
		
############################################## NOMS INCORRECTS #############################################	

my $nothonyms = getNothonyms($gid, 'disponible'); # dico des noms incorrects 
my $errornotho = getNothonyms($gid, 'indisponible'); # dico des erreurs d'orthographe;
my @list;
my $nothotext;


if (scalar(keys(%{$nothonyms}))) {

	
	my $periodval;
	my $nextmorphos;
	my %denombrenextgenus;
	my %denombrelastgenus;
	my $periodajout;
	if ($fullh) {
		$nothotext = span ({-class=> 'text'},"$traduction->{'taxainvalspelife'}->{$xlang} : ").br.br;
	}
	else {
		$nothotext = span ({-class=> 'text'},"$traduction->{'taxainvspelist'}->{$xlang} : ").br.br;
	}

	foreach my $id  (keys %{$nothonyms}) {
		
		
		$nextmorphos = getMorphonyms($nothonyms->{$id}, 'next', 'disponible'); # recherche des morphonymes suivants
						
		my $lastmorpho = getMorphonym($nothonyms->{$id}, 'last');
		my $nextmorpho = getMorphonym($nothonyms->{$id}, 'next');
		my ($nextid) = keys (%{$nextmorpho});	
		my ($lastid) = keys (%{$lastmorpho});

		foreach my $id (keys %{$nextmorpho}) {
			 @list = sort {$a <=> $b} $nextmorpho->{$id}{'annee_validite'};
		}
		
		my $nextgenus = $nextmorpho->{$nextid}{'genre'};
		my $nextgenusauthors = getTaxonomists($nextmorpho->{$nextid}{'gindex'}, 'auteurs');
		
		my $lastgenus = $lastmorpho->{$lastid}{'genre'};
		my $lastgenusauthors = getTaxonomists($lastmorpho->{$lastid}{'gindex'}, 'auteurs');
		
		if ($nextgenus =~ m/[A-Z]./) {
			if ($denombrenextgenus{$nextgenus}) { 
				$denombrenextgenus{$nextgenus}{'compt'}++;
				
			}
			else { 
				$denombrenextgenus{$nextgenus}{'compt'} = 1;
				$denombrenextgenus{$nextgenus}{'autority'} = "$nextgenusauthors, $nextmorpho->{$nextid}{gannee}";
			}
		}
		
		if ($lastgenus =~ m/[A-Z]./) {
			if ($denombrelastgenus{$lastgenus}) { 
				$denombrelastgenus{$lastgenus}{'comp'}++;
				
			}
			else { 
				$denombrelastgenus{$lastgenus}{'comp'} = 1;
				$denombrelastgenus{$lastgenus}{'autorit'} = "$lastgenusauthors, $lastmorpho->{$lastid}{gannee}";
			}
		}
		
		
	}
	
	my $nothoshistories;
	my $m= 1; # compteur pour calculer nb de nothonymes
	my $orinotho = 0;
	
	
		
	foreach my $id  ( sort {$nothonyms->{$a}{annee_princeps} <=> $nothonyms->{$b}{annee_princeps}
	|| $nothonyms->{$a}{espece} cmp $nothonyms->{$b}{espece}} keys(%{$nothonyms})) {
	
		if (($nothonyms->{$id}{annee_princeps} == $genusdate && (!$nothonyms->{$id}{parentheses})) || ($nothonyms->{$id}{annee_validite} == $genusdate)) {
			$orinotho++;
		}
		
		if ($fullh) {
			my $k=1; # pour l'indentation de l'historique
			
			my $nextmorpho = getMorphonym($nothonyms->{$id}, 'next');
			my ($nextid) = keys (%{$nextmorpho});	
			$periodval =  getPeriodValiditymorpho ($nextmorpho->{$nextid}, $nothonyms->{$id});
				
			my $allmorphos = getMorphonyms($nothonyms->{$id}, 'all', 'disponible'); # recherche de tous les morphonymes
			
			my @sortedcles = sort {$allmorphos->{$a}{annee_validite} <=> $allmorphos->{$b}{annee_validite}} (keys (%{$allmorphos}));
			
			foreach my $id (@sortedcles) {
				if ($allmorphos->{$id}{erreur} =~ m/^$/) {
					
					my $nothohistory .= formatNamesSpecies($allmorphos->{$id});
					
					my $homosprimrecent = getHomonyms($allmorphos->{$id}, 'homonymie primaire', 'plus_recents');
					my $homosseconrecent = getHomonyms($allmorphos->{$id}, 'homonymie secondaire', 'plus_recents');
						 
					my $homosprimancien = getHomonyms($allmorphos->{$id}, 'homonymie primaire', 'plus_anciens');
					my $homosseconancien = getHomonyms($allmorphos->{$id}, 'homonymie secondaire', 'plus_anciens');
						
					my $archeo = getArcheo($allmorphos->{$id}, 'neonymie', 'plus_ancien');
					my $lastsyn = getArcheo($allmorphos->{$id}, 'nom de remplacement par synonymie', 'plus_ancien');
					my $neonyme = getArcheo($allmorphos->{$id}, 'neonymie', 'plus_recent');
					my $juniorsyn = getArcheo($allmorphos->{$id}, 'nom de remplacement par synonymie', 'plus_recent');
					
					my @statut;
					my @synonymies;
					my @homonymies;
					
					if ($homosprimrecent) { 
						foreach my $id (keys %{$homosprimrecent}) {
							push(@homonymies,formatNamesSpecies($homosprimrecent->{$id}));
						 }
					}
					if ($homosseconrecent) { 
						foreach my $id (keys %{$homosseconrecent}) {
								push(@homonymies,formatNamesSpecies($homosseconrecent->{$id}));
						 }
					} 				
					if ($homosprimancien) {
						foreach my $id (keys %{$homosprimancien}) {
							push(@homonymies,formatNamesSpecies($homosprimancien->{$id}));
						}
					}				
					if ($homosseconancien) { 
						foreach my $id (keys %{$homosseconancien}) {
							push(@homonymies,formatNamesSpecies($homosseconancien->{$id}))
						}
					}
							
					if ($archeo) { push(@statut,'nomen novum de ') ;push(@synonymies,$archeo) };
					if ($lastsyn) { push(@statut,'ancien synonyme subjectif de ');push(@synonymies,$lastsyn) };
					if ($neonyme) { push(@statut,'nom plus ancien de ') ;push(@synonymies,$neonyme) };
					if ($juniorsyn) { push(@statut,'synonyme subjectif plus recent ');push(@synonymies,$juniorsyn) };	
			
					if (scalar(@homonymies)) {
						$nothohistory .= " [non ".join ('; nec ', @homonymies)." ]";
					}
					
					if (scalar (@synonymies)) {
						my $j=0;
						foreach my $type (@synonymies) {
							foreach my $id (keys %{$type}) {	
							 $nothohistory .= " [ $statut[$j]".formatNamesSpecies($type->{$id})."]";
							}
						$j++;
						}
					}
					
					if (scalar(@sortedcles) > 1) {
						if ($k == scalar(@sortedcles)) {
							$nothohistory = span ({-style=>'position:relative; left:60px;'},$nothohistory);
						}
						else {
							if ($k == 1) { $nothohistory = "$m- $nothohistory" } 
							else { $nothohistory = span ({-style=>'position:relative; left:40px;'},$nothohistory); }
						}
					$k++;
					}
					$nothoshistories .= $nothohistory . br;
				}
			}	
		
		$periodajout += $periodval;
		$m++;
	
		}
	
		else  {
				my $nothohistory.= formatNamesSpecies($nothonyms->{$id});
				$nothoshistories.= "$m- $nothohistory" . br;
				my $nextmorpho = getMorphonym($nothonyms->{$id}, 'next');
				my ($nextid) = keys (%{$nextmorpho});	
				$periodval =  getPeriodValiditymorpho ($nextmorpho->{$nextid}, $nothonyms->{$id});			
				$periodajout += $periodval ;
				$m++;
			}
		}
	
	$nothotext .= $nothoshistories.br;
	
	my $sommenotho;
	my $lastvalnotho = pop @list;
	
	if (!$lastvaleunym) {
		$status .= "$traduction->{'taxainvalsince'}->{$xlang} $lastvalnotho".br;
	}	
	elsif ($lastvaleunym > $lastvalnotho) {
		$status .= "$traduction->{'taxainterval'}->{$xlang} $lastvalnotho $traduction->{'taxaand'}->{$xlang} $lastvaleunym".br;
	}
	
	if ($orinotho != 0) {
			$status .= "$traduction->{'taxaorispecies'}->{$xlang} $orinotho $traduction->{'taxaspecies'}->{$xlang}".br;
		}
		
	$nothoabstract .= "$traduction->{'taxanow'}->{$xlang} ".($m-1)." $traduction->{'taxainvspe'}->{$xlang}".br;
	$nothoabstract .= "$traduction->{'taxalifemean'}->{$xlang} : ". int ($periodajout/($m-1))." $traduction->{'taxayears'}->{$xlang}".br;
	

	foreach (keys %denombrenextgenus) {
		#$nothoabstract .= "$denombrenextgenus{$_}{compt} $traduction->{'taxaimtranf'}->{$xlang} ".span ({-class=> 'italic'}, "$_")." $denombrenextgenus{$_}{autority} ". br;
		$sommenotho += $denombrenextgenus{$_}{compt};
	}
	
	if (($m - $sommenotho) != 0) {
		#$nothoabstract .= "et ".($m - $sommenotho). " homonymes plus recents".br;
	}
		
	#if (scalar (keys %{$nextmorphos})>=2) {
		foreach (keys %denombrelastgenus) {
			$nothoabstract .= "$denombrelastgenus{$_}{comp} $traduction->{'taxatransfert'}->{$xlang} ".span ({-class=> 'italic'}, "$_")." $denombrelastgenus{$_}{autorit} ". br;
		}
	#}		
}	
########################################### RESUME ##########################################

my @rubrik;
my @abstract;
my $lastmodif = request_tab ("SELECT  date_modification FROM noms WHERE index = $gid;",$dbconnect, 1);
my $lastupdate = span ({-style=>'font-size:x-small'},"$traduction->{'taxaupdate'}->{$xlang} : $lastmodif->[0]");
	
if ($abst) {
	foreach my $id (keys %{$infotaxon}) {
		my $author = getTaxonomists ($gid,'auteurs');
		$caption = span ({-class=> 'italic'},"$infotaxon->{$id}{'genre'}")." $author, $infotaxon->{$id}{'annee_genre'}"; 	
		
		if ($eunymabstract) {
			push (@rubrik,"$traduction->{'taxavalspe'}->{$xlang}");
			push (@abstract,$eunymabstract);
		}
		if ($nothoabstract) {
			push (@rubrik,"$traduction->{'taxainvspe'}->{$xlang}");
			push (@abstract,$nothoabstract);
		
		}
	
	}
}
########################################## CREATION PAGE WEB ##################################################
print header(),

start_html (
	-title => "$traduction->{'taxahist'}->{$xlang} $title",
	-style  => {'src'=>'/Taxalifedocs/taxalife.css'},
	-statut => 'historique',
	-authors => 'aodent@hotmail.fr',
	-head => meta ({-http_equiv => 'Content-Type', 
					-content => 'text/html; charset = iso-8859-15',
					}),
),
div({-id=>'header'},img({-src=>'/flowdocs/bandeauFLOW.png', -alt=>"header", -width=>'980px'})),
div ({-class=>'centerdiv'},$genuslife);


 
if ($abst) {
	
	print 	table({-class=> 'table', cellspacing=>'10px', },
			Tr([ td ({-colspan=>'2', -align=>'center'}, $caption) ]),
			Tr([	td ($status),
				td ($genusintro),
			  	th ([@rubrik]),
			  	td ([@abstract]),
			  	td ({-colspan=>'2', -align=>'center'},$lastupdate) ])
		), br
}
else {
	print 	table({-class=> 'table', cellspacing=>'10px', },
			Tr([ td ({-colspan=>'2', -align=>'center'}, $caption) ]),
			Tr([	
				td ($genusintro),
			  	td ({-colspan=>'2', -align=>'center'},$lastupdate) ])
		), br
};

print 	div ({ -style=> 'margin:auto auto; width:700px;'},		
		$eunymtext,
		$nothotext,

		div ({-class => 'taxaposlien'},
			a( {href=>"/cgi-bin/flowsite.pl?base=flow&page=home&lang=$xlang", class=>'lien'}," $traduction->{'taxaflow'}->{$xlang}" )." >> ". 
			a( {href=>"/cgi-bin/Taxalife/taxalife.pl?lang=$xlang", class=>'lien'}," $traduction->{'taxahome'}->{$xlang}")." >> ". 
			a( {href=>"/cgi-bin/Taxalife/taxagenchoice.pl?lang=$xlang", class=>'lien'},"$traduction->{'taxagenchoice'}->{$xlang}")." >> ".
			"$traduction->{'taxahist'}->{$xlang} $caption"
		),
);


print end_html();

$dbconnect->disconnect();
#$dbc->disconnect();
