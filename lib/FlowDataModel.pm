use utf8;
use strict;
use warnings;
use DBIx::DataModel;

DBIx::DataModel  # no semicolon (intentional)

#---------------------------------------------------------------------#
#                         SCHEMA DECLARATION                          #
#---------------------------------------------------------------------#
->Schema('FlowDataModel')

#---------------------------------------------------------------------#
#                         TABLE DECLARATIONS                          #
#---------------------------------------------------------------------#
#          Class                 Table                    PK        
#          =====                 =====                    ==        
->Table(qw/Agents                agents                   index     /)
->Table(qw/Auteurs               auteurs                  index     /)
->Table(qw/AuteursXPublications  auteurs_x_publications   ref_auteur ref_publication/)
->Table(qw/Dbinfo                dbinfo                   gsdid     /)
->Table(qw/DisplayModes          display_modes            card element/)
->Table(qw/Documents             documents                index     /)
->Table(qw/Editions              editions                 index     /)
->Table(qw/EtatsConservation     etats_conservation       index     /)
->Table(qw/Familles              familles                 index     /)
->Table(qw/Habitats              habitats                 index     /)
->Table(qw/Hierarchie            hierarchie               index_taxon_parent index_taxon_fils/)
->Table(qw/HoltRealms            holt_realms              index     /)
->Table(qw/HoltRegions           holt_regions             index     /)
->Table(qw/Images                images                   index     /)
->Table(qw/Langages              langages                 index     /)
->Table(qw/LieuxDepot            lieux_depot              index     /)
->Table(qw/Lithostrats           lithostrats              index     /)
->Table(qw/Localites             localites                index     /)
->Table(qw/ModesCapture          modes_capture            index     /)
->Table(qw/Molecular             molecular                index     /)
->Table(qw/NiveauxConfirmation   niveaux_confirmation     index     /)
->Table(qw/NiveauxFrequence      niveaux_frequence        index     /)
->Table(qw/NiveauxGeologiques    niveaux_geologiques      index     /)
->Table(qw/Noms                  noms                     index     /)
->Table(qw/NomsComplets          noms_complets            index     /) # missing PK constraint
->Table(qw/NomsVernaculaires     noms_vernaculaires       index     /)
->Table(qw/NomsXAuteurs          noms_x_auteurs           ref_nom ref_auteur/)
->Table(qw/NomsXImages           noms_x_images            ref_nom ref_image/)
->Table(qw/NomsXTypes            noms_x_types             ref_nom ref_type/)
->Table(qw/Pays                  pays                     index     /) # missing PK constraint
->Table(qw/Periodes              periodes                 index     /)
->Table(qw/Plantes               plantes                  index     /)
->Table(qw/Publications          publications             index     /)
->Table(qw/Rangs                 rangs                    index     /)
->Table(qw/Reencode              reencode                 ascii     /) # missing PK constraint -- ascii not really a key
->Table(qw/Regions               regions                  index     /)
->Table(qw/RegionsBiogeo         regions_biogeo           index     /)
->Table(qw/Revues                revues                   index     /)
->Table(qw/Sexes                 sexes                    index     /)
->Table(qw/Statuts               statuts                  index     /)
->Table(qw/Synopsis              synopsis                 ordre sous_ordre super_famille famille/) # proper pk ? guess ...
->Table(qw/Taxons                taxons                   index     /)
->Table(qw/TaxonsAssocies        taxons_associes          index     /)
->Table(qw/TaxonsXDocuments      taxons_x_documents       ref_taxon ref_document/)
->Table(qw/TaxonsXImages         taxons_x_images          ref_taxon ref_image/)
->Table(qw/TaxonsXNoms           taxons_x_noms            ref_taxon ref_nom/)
->Table(qw/TaxonsXPays           taxons_x_pays            ref_taxon ref_pays/)
->Table(qw/TaxonsXPeriodes       taxons_x_periodes        ref_taxon ref_periode/)
->Table(qw/TaxonsXPlantes        taxons_x_plantes         ref_taxon ref_plante/)
->Table(qw/TaxonsXRegionsBiogeo  taxons_x_regions_biogeo  ref_taxon ref_region_biogeo/)
->Table(qw/TaxonsXSites          taxons_x_sites           ref_taxon ref_site/)
->Table(qw/TaxonsXTaxonsAssocies taxons_x_taxons_associes ref_taxon ref_taxon_associe/)
->Table(qw/TaxonsXVernaculaires  taxons_x_vernaculaires   ref_taxon ref_vernaculaire/)
->Table(qw/TxnToTxt              txn_to_txt               taxon     /) # guess
->Table(qw/TypesAgent            types_agent              index     /)
->Table(qw/TypesAssociation      types_association        index     /)
->Table(qw/TypesCavernicolous    types_cavernicolous      index     /)
->Table(qw/TypesDepot            types_depot              index     /)
->Table(qw/TypesDesignation      types_designation        index     /) # missing PK constraint
->Table(qw/TypesObservation      types_observation        index     /)
->Table(qw/TypesPreservation     types_preservation       index     /)
->Table(qw/TypesPublication      types_publication        index     /)
->Table(qw/TypesType             types_type               index     /)
->Table(qw/Villes                villes                   index     /)

#---------------------------------------------------------------------#
#                      ASSOCIATION DECLARATIONS                       #
#---------------------------------------------------------------------#
#     Class                 Role                        Mult Join
#     =====                 ====                        ==== ====
->Association(
  [qw/Auteurs               auteur                      1    index                          /],
  [qw/AuteursXPublications  auteurs_x_publications      *    ref_auteur                     /])

->Association(
  [qw/Auteurs               auteur                      1    index                          /],
  [qw/NomsXAuteurs          noms_x_auteurs              *    ref_auteur                     /])

->Association(
  [qw/Documents             document                    1    index                          /],
  [qw/TaxonsXDocuments      taxons_x_documents          *    ref_document                   /])

->Association(
  [qw/Editions              edition                     1    index                          /],
  [qw/Publications          publications                *    ref_edition                    /])

->Association(
  [qw/EtatsConservation     etats_conservation          1    index                          /],
  [qw/NomsXTypes            noms_x_types                *    ref_etat_conservation          /])

->Association(
  [qw/HoltRealms            holt_realm                  1    index                          /],
  [qw/HoltRegions           holt_regions                *    ref_realm                      /])

->Association(
  [qw/HoltRegions           holt_region                 1    index                          /],
  [qw/Pays                  pays                        *    ref_holt                       /])

->Association(
  [qw/Images                image                       1    index                          /],
  [qw/NomsXImages           noms_x_images               *    ref_image                      /])

->Association(
  [qw/Images                image                       1    index                          /],
  [qw/TaxonsXImages         taxons_x_images             *    ref_image                      /])

->Association(
  [qw/Langages              langage                     1    index                          /],
  [qw/NomsVernaculaires     noms_vernaculaires          *    ref_langage                    /])

->Association(
  [qw/LieuxDepot            lieux_depot                 1    index                          /],
  [qw/NomsXTypes            noms_x_types                *    ref_lieux_depot                /])

->Association(
  [qw/Lithostrats           lithostrat                  1    index                          /],
  [qw/Lithostrats           lithostrats                 *    parent                         /])

->Association(
  [qw/Lithostrats           lithostrat                  1    index                          /],
  [qw/TaxonsXSites          taxons_x_sites              *    ref_lithostrat                 /])

->Association(
  [qw/Localites             localite                    1    index                          /],
  [qw/TaxonsXSites          taxons_x_sites              *    ref_localite                   /])

->Association(
  [qw/NiveauxFrequence      niveaux_frequence           1    index                          /],
  [qw/TaxonsXRegionsBiogeo  taxons_x_regions_biogeos    *    ref_niveau_frequence           /])

->Association(
  [qw/NiveauxGeologiques    niveaux_geologique          1    index                          /],
  [qw/Periodes              periodes                    *    niveau                         /])

->Association(
  [qw/Noms                  nom                         1    index                          /],
  [qw/Noms                  noms                        *    ref_nom_parent                 /])

->Association(
  [qw/Noms                  nom                         1    index                          /],
  [qw/NomsXAuteurs          noms_x_auteurs              *    ref_nom                        /])

->Association(
  [qw/Noms                  nom                         1    index                          /],
  [qw/NomsXImages           noms_x_images               *    ref_nom                        /])

->Association(
  [qw/Noms                  nom                         1    index                          /],
  [qw/NomsXTypes            noms_x_types                *    ref_nom                        /])

->Association(
  [qw/Noms                  nom                         1    index                          /],
  [qw/TaxonsXDocuments      taxons_x_documents          *    ref_nom                        /])

->Association(
  [qw/Noms                  nom                         1    index                          /],
  [qw/TaxonsXImages         taxons_x_images             *    ref_nom                        /])

->Association(
  [qw/Noms                  nom                         1    index                          /],
  [qw/TaxonsXNoms           taxons_x_noms               *    ref_nom_cible                  /])

->Association(
  [qw/Noms                  nom_2                       1    index                          /],
  [qw/TaxonsXNoms           taxons_x_noms_2             *    ref_nom                        /])

->Association(
  [qw/Noms                  nom                         1    index                          /],
  [qw/TaxonsXPays           taxons_x_pays               *    ref_nom                        /])

->Association(
  [qw/Noms                  nom_2                       1    index                          /],
  [qw/TaxonsXPays           taxons_x_pays_2             *    ref_nom_specifique_femelle     /])

->Association(
  [qw/Noms                  nom_3                       1    index                          /],
  [qw/TaxonsXPays           taxons_x_pays_3             *    ref_nom_specifique_male        /])

->Association(
  [qw/Noms                  nom_4                       1    index                          /],
  [qw/TaxonsXPays           taxons_x_pays_4             *    ref_nom_specifique_sexe_inconnu/])

->Association(
  [qw/Noms                  nom                         1    index                          /],
  [qw/TaxonsXPeriodes       taxons_x_periodes           *    ref_nom                        /])

->Association(
  [qw/Noms                  nom                         1    index                          /],
  [qw/TaxonsXRegionsBiogeo  taxons_x_regions_biogeos    *    ref_nom                        /])

->Association(
  [qw/Noms                  nom                         1    index                          /],
  [qw/TaxonsXSites          taxons_x_sites              *    ref_nom                        /])

->Association(
  [qw/Noms                  nom                         1    index                          /],
  [qw/TaxonsXTaxonsAssocies taxons_x_taxons_associes    *    ref_nom                        /])

->Association(
  [qw/Noms                  nom                         1    index                          /],
  [qw/TaxonsXVernaculaires  taxons_x_vernaculaires      *    ref_nom                        /])

->Association(
  [qw/NomsVernaculaires     noms_vernaculaire           1    index                          /],
  [qw/TaxonsXVernaculaires  taxons_x_vernaculaires      *    ref_vernaculaire               /])

->Association(
  [qw/Pays                  pay                         1    index                          /],
  [qw/LieuxDepot            lieux_depots                *    ref_pays                       /])

->Association(
  [qw/Pays                  pay                         1    index                          /],
  [qw/Localites             localites                   *    ref_pays                       /])

->Association(
  [qw/Pays                  pay                         1    index                          /],
  [qw/NomsVernaculaires     noms_vernaculaires          *    ref_pays                       /])

->Association(
  [qw/Pays                  pay                         1    index                          /],
  [qw/Regions               regions                     *    ref_pays                       /])

->Association(
  [qw/Pays                  pay                         1    index                          /],
  [qw/TaxonsXPays           taxons_x_pays               *    ref_pays                       /])

->Association(
  [qw/Pays                  pay                         1    index                          /],
  [qw/Villes                villes                      *    ref_pays                       /])

->Association(
  [qw/Periodes              periode                     1    index                          /],
  [qw/Periodes              periodes                    *    parent                         /])

->Association(
  [qw/Periodes              periode                     1    index                          /],
  [qw/TaxonsXPeriodes       taxons_x_periodes           *    ref_periode                    /])

->Association(
  [qw/Periodes              periode                     1    index                          /],
  [qw/TaxonsXSites          taxons_x_sites              *    ref_periode                    /])

->Association(
  [qw/Plantes               plante                      1    index                          /],
  [qw/Plantes               plantes                     *    ref_parent                     /])

->Association(
  [qw/Plantes               plante_2                    1    index                          /],
  [qw/Plantes               plantes_2                   *    ref_valide                     /])

->Association(
  [qw/Publications          publication                 1    index                          /],
  [qw/AuteursXPublications  auteurs_x_publications      *    ref_publication                /])

->Association(
  [qw/Publications          publication                 1    index                          /],
  [qw/Noms                  noms                        *    ref_publication_designation    /])

->Association(
  [qw/Publications          publication_2               1    index                          /],
  [qw/Noms                  noms_2                      *    ref_publication_princeps       /])

->Association(
  [qw/Publications          publication                 1    index                          /],
  [qw/NomsXTypes            noms_x_types                *    ref_pub                        /])

->Association(
  [qw/Publications          publication                 1    index                          /],
  [qw/Publications          publications                *    ref_publication_livre          /])

->Association(
  [qw/Publications          publication                 1    index                          /],
  [qw/TaxonsXNoms           taxons_x_noms               *    ref_publication_denonciation   /])

->Association(
  [qw/Publications          publication_2               1    index                          /],
  [qw/TaxonsXNoms           taxons_x_noms_2             *    ref_publication_utilisant      /])

->Association(
  [qw/Publications          publication                 1    index                          /],
  [qw/TaxonsXPays           taxons_x_pays               *    ref_publication_femelle        /])

->Association(
  [qw/Publications          publication_2               1    index                          /],
  [qw/TaxonsXPays           taxons_x_pays_2             *    ref_publication_maj            /])

->Association(
  [qw/Publications          publication_3               1    index                          /],
  [qw/TaxonsXPays           taxons_x_pays_3             *    ref_publication_male           /])

->Association(
  [qw/Publications          publication_4               1    index                          /],
  [qw/TaxonsXPays           taxons_x_pays_4             *    ref_publication_ori            /])

->Association(
  [qw/Publications          publication_5               1    index                          /],
  [qw/TaxonsXPays           taxons_x_pays_5             *    ref_publication_sexe_inconnu   /])

->Association(
  [qw/Publications          publication                 1    index                          /],
  [qw/TaxonsXPeriodes       taxons_x_periodes           *    ref_publication_maj            /])

->Association(
  [qw/Publications          publication_2               1    index                          /],
  [qw/TaxonsXPeriodes       taxons_x_periodes_2         *    ref_publication_ori            /])

->Association(
  [qw/Publications          publication                 1    index                          /],
  [qw/TaxonsXRegionsBiogeo  taxons_x_regions_biogeos    *    ref_publication_maj            /])

->Association(
  [qw/Publications          publication_2               1    index                          /],
  [qw/TaxonsXRegionsBiogeo  taxons_x_regions_biogeos_2  *    ref_publication_ori            /])

->Association(
  [qw/Publications          publication                 1    index                          /],
  [qw/TaxonsXSites          taxons_x_sites              *    ref_pub_maj                    /])

->Association(
  [qw/Publications          publication_2               1    index                          /],
  [qw/TaxonsXSites          taxons_x_sites_2            *    ref_pub_ori                    /])

->Association(
  [qw/Publications          publication                 1    index                          /],
  [qw/TaxonsXTaxonsAssocies taxons_x_taxons_associes    *    ref_publication_maj            /])

->Association(
  [qw/Publications          publication_2               1    index                          /],
  [qw/TaxonsXTaxonsAssocies taxons_x_taxons_associes_2  *    ref_publication_ori            /])

->Association(
  [qw/Publications          publication                 1    index                          /],
  [qw/TaxonsXVernaculaires  taxons_x_vernaculaires      *    ref_pub                        /])

->Association(
  [qw/Rangs                 rang                        1    index                          /],
  [qw/Noms                  noms                        *    ref_rang                       /])

->Association(
  [qw/Rangs                 rang                        1    index                          /],
  [qw/Plantes               plantes                     *    ref_rang                       /])

->Association(
  [qw/Rangs                 rang                        1    index                          /],
  [qw/TaxonsAssocies        taxons_associes             *    ref_rang                       /])

->Association(
  [qw/Rangs                 rang                        1    index                          /],
  [qw/Taxons                taxons                      *    ref_rang                       /])

->Association(
  [qw/RegionsBiogeo         regions_biogeo              1    index                          /],
  [qw/HoltRealms            holt_realms                 *    ref_biogeo                     /])

->Association(
  [qw/RegionsBiogeo         regions_biogeo              1    index                          /],
  [qw/Pays                  pays                        *    ref_biogeo                     /])

->Association(
  [qw/RegionsBiogeo         regions_biogeo              1    index                          /],
  [qw/TaxonsXRegionsBiogeo  taxons_x_regions_biogeos    *    ref_region_biogeo              /])

->Association(
  [qw/Revues                revue                       1    index                          /],
  [qw/Publications          publications                *    ref_revue                      /])

->Association(
  [qw/Sexes                 sex                         1    index                          /],
  [qw/NomsXTypes            noms_x_types                *    ref_sexe                       /])

->Association(
  [qw/Sexes                 sex                         1    index                          /],
  [qw/TaxonsXTaxonsAssocies taxons_x_taxons_associes    *    ref_sexe                       /])

->Association(
  [qw/Statuts               statut                      1    index                          /],
  [qw/TaxonsXNoms           taxons_x_noms               *    ref_statut                     /])

->Association(
  [qw/Taxons                taxon                       1    index                          /],
  [qw/Taxons                taxons                      *    ref_taxon_parent               /])

->Association(
  [qw/Taxons                taxon                       1    index                          /],
  [qw/TaxonsXDocuments      taxons_x_documents          *    ref_taxon                      /])

->Association(
  [qw/Taxons                taxon                       1    index                          /],
  [qw/TaxonsXImages         taxons_x_images             *    ref_taxon                      /])

->Association(
  [qw/Taxons                taxon                       1    index                          /],
  [qw/TaxonsXNoms           taxons_x_noms               *    ref_taxon                      /])

->Association(
  [qw/Taxons                taxon                       1    index                          /],
  [qw/TaxonsXPays           taxons_x_pays               *    ref_taxon                      /])

->Association(
  [qw/Taxons                taxon                       1    index                          /],
  [qw/TaxonsXPeriodes       taxons_x_periodes           *    ref_taxon                      /])

->Association(
  [qw/Taxons                taxon                       1    index                          /],
  [qw/TaxonsXSites          taxons_x_sites              *    ref_taxon                      /])

->Association(
  [qw/Taxons                taxon                       1    index                          /],
  [qw/TaxonsXTaxonsAssocies taxons_x_taxons_associes    *    ref_taxon                      /])

->Association(
  [qw/Taxons                taxon                       1    index                          /],
  [qw/TaxonsXVernaculaires  taxons_x_vernaculaires      *    ref_taxon                      /])

->Association(
  [qw/TaxonsAssocies        taxons_assocy               1    index                          /],
  [qw/TaxonsAssocies        taxons_associes             *    ref_parent                     /])

->Association(
  [qw/TaxonsAssocies        taxons_assocy_2             1    index                          /],
  [qw/TaxonsAssocies        taxons_associes_2           *    ref_valide                     /])

->Association(
  [qw/TaxonsAssocies        taxons_assocy               1    index                          /],
  [qw/TaxonsXTaxonsAssocies taxons_x_taxons_associes    *    ref_taxon_associe              /])

->Association(
  [qw/TypesAgent            types_agent                 1    index                          /],
  [qw/Agents                agents                      *    ref_type_agent                 /])

->Association(
  [qw/TypesAssociation      types_association           1    index                          /],
  [qw/TaxonsXTaxonsAssocies taxons_x_taxons_associes    *    ref_type_association           /])

->Association(
  [qw/TypesDepot            types_depot                 1    index                          /],
  [qw/NomsXTypes            noms_x_types                *    ref_type_depot                 /])

->Association(
  [qw/TypesDesignation      types_designation           1    index                          /],
  [qw/Noms                  noms                        *    ref_type_designation           /])

->Association(
  [qw/TypesPreservation     types_preservation          1    index                          /],
  [qw/NomsXTypes            noms_x_types                *    ref_type_preservation          /])

->Association(
  [qw/TypesPublication      types_publication           1    index                          /],
  [qw/Publications          publications                *    ref_type_publication           /])

->Association(
  [qw/TypesType             types_type                  1    index                          /],
  [qw/NomsXTypes            noms_x_types                *    ref_type                       /])

->Association(
  [qw/Villes                ville                       1    index                          /],
  [qw/Editions              editions                    *    ref_ville                      /])

;

#---------------------------------------------------------------------#
#                             COLUMN TYPES                            #
#---------------------------------------------------------------------#
# My::Schema->ColumnType(ColType_Example =>
#   fromDB => sub {...},
#   toDB   => sub {...});

# My::Schema::SomeTable->ColumnType(ColType_Example =>
#   qw/column1 column2 .../);



1;
