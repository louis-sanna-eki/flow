


sub test_pub {
	
	my ($type) = @_;
	my $respons = "ok";
	
	my $statut = param($type.".type.p");
	
	if ($statut == '') { #If it's a Book
		
		unless (param($type.".title")) { $respons = "A Book must have a Title...";}
		else {
			unless (param($type.".siecle") and param($type.".annee")) { $respons = "A Book must have a valid Year..."; }
			else {
				if (param($type.".fascicule")) { $respons = "A Book can't have a Fascicule number..."; }
				else {
					if (param($type.".revue.t") or (param($type.".revue.p") and  param($type.".revue.p") ne "Select")) { $respons = "A Book can't be linked to a Revue..."; }
					else {
						#unless (param($type.".edition.t") or param($type.".edition.p") ne "Select") { $respons = "A Book must have an Edition..."; }
						#else {
							if (param("$type.bookref")) { $respons = "A Book can't be included in another Book..."; }
							else {
								unless (param("$type.author1.t.p") or param("$type.author1.p") ne "Select") { $respons = "A Book must have at least one Author..."; }
							}
						#}
					}
				}
			}
		}
	} 
	elsif ($statut == 2) { #If it's an Article
		
		#unless (param($type.".title")) { $respons = "An Article must have a Title...";}
		#else {
			unless (param($type.".siecle") and param($type.".annee")) { $respons = "An Article must have a valid Year..."; }
			else {
				unless (param($type.".volume")) { $respons = "An Article must have at least a Volume number...";}
				else {
					# Deux cas ici: si on cree un bouquin a partir de pub: revue = select par defaut mais a partir de book revue n'existe pas d'ou le double test
					unless (param($type.".revue.t") or param($type.".revue.p") ne "Select") { $respons = "An Article must be linked to a Revue..."; }
					else {
						if (param($type.".edition.t") or param($type.".edition.p") ne "Select") { $respons = "An Article can't have an Edition..."; }
						else {
							unless (param($type.".page.debut") ) { $respons = "An Article must at least have a Page index..."; }
							else {
								if (param("$type.bookref")) { $respons = "An Article can't be included in a Book; perhaps you should try as In Book..."; }
								else {
									unless (param("$type.author1.t.p") or param("$type.author1.p") ne "Select") { $respons = "An Article must have at least one Author..."; }
								}
							}
						}
					}
				}
			}
		#}
		
	}
	elsif ($statut == 3) { #If it's a Thesis
		
		unless (param($type.".title")) { $respons = "A Thesis must have a Title...";}
		else {
			unless (param($type.".siecle") and param($type.".annee")) { $respons = "A Thesis must have a valid Year..."; }
			else {
				if (param($type.".volume")) { $respons = "A Thesis can't have a Volume number...";}
				else {
					if (param($type.".fascicule")) { $respons = "A Thesis can't have a Fascicule number...";}
					else {
						if (param($type.".revue.t") or param($type.".revue.p") ne "Select") { $respons = "A Thesis can't be linked to a Revue..."; }
						else {
							unless (param($type.".edition.t") or param($type.".edition.p") ne "Select") { $respons = "A Thesis must have an Edition..."; }
							else {
								unless (param($type.".page.debut") and param($type.".page.fin")) { $respons = "A Thesis must have a Page interval..."; }
								else {
									if (param("$type.bookref")) { $respons = "A Thesis can't be included in a Book; perhaps you should try as In Book..."; }
									else {
										unless (param("$type.author1.t.p") or param("$type.author1.p") ne "Select") { $respons = "A Thesis must have an Author..."; }
										else {
											unless (param("$type.author2.t.p") or param("$type.author2.p") ne "Select") { $respons = "A Thesis must have only one Author..."; }
										}
									}
								}
							}
						}
					}
				}
			}
		}
		
	}	
	elsif ($statut == 4) { #If it's an In Book
		
		#unless (param($type.".title")) { $respons = "An In Book must have a Title...";}
		#else {
			if (param($type.".volume")) { $respons = "An In Book can't have a Volume number...";}
			else {
				if (param($type.".fascicule")) { $respons = "An In Book can't have a Fascicule number...";}
				else {
					if (param($type.".revue.t") or param($type.".revue.p") ne "Select") { $respons = "An In Book can't be linked to a Revue..."; }
					else {
						if (param($type.".edition.t") or param($type.".edition.p") ne "Select") { $respons = "An In Book can't have an Edition..."; }
						else {
							#unless (param($type.".page.debut") and param($type.".page.fin")) { $respons = "An In Book must have a Page interval..."; }
							#else {
								unless (param("$type.bookref")) { $respons = "An In Book need a Book reference (logically)..."; }
								else {
									unless (param("$type.author1.t.p") or param("$type.author1.p") ne "Select") { $respons = "An In Book must have at least one Author..."; }
								}
							#}
						}
					}
				}
			}
		#}
		
	}
	else { $respons = "What is the Type of the Publication?"; }
	
	return $respons;
}
