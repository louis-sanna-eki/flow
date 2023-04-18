BEGIN;
create table types_preservation (index serial primary key, nom text);
alter table noms_x_types add ref_type_preservation integer references types_preservation(index);
alter table noms_x_types add immatriculation text;
alter table niveaux_geologiques add pt text;
alter table niveaux_geologiques add pl text;
create table niveaux_litho (index serial primary key, fr text, en text, es text, pt text, de text, zh text, pl text);
create table lithostrats (index serial primary key, fr text, en text, es text, pt text, de text, zh text, pl text, niveau integer references niveaux_litho(index), parent integer references lithostrat(index));
create table localites (index serial primary key, nom text, ref_pays integer references pays(index));
create table taxons_x_sites (ref_taxon integer references taxons(index), ref_nom integer references noms(index), ref_localite integer references localites(index), ref_lithostrat integer references lithostrat(index), ref_periode integer references periodes(index), ref_periode2 integer references periodes(index), ref_pub_ori integer references publications(index), ref_pub_maj integer references publications(index), page_ori text, page_maj text, createur text, date_creation date default ('now'::text)::date, modificateur text, date_modification date default ('now'::text)::date, afficher boolean);
alter table periodes add hex_color text;
ALTER TABLE taxons_x_sites SET WITH oids;


grant select on types_preservation to web;
grant select on niveaux_litho to web;
grant select on lithostrat to web;
grant select on localites to web;
grant select on taxons_x_sites to web;

grant all on types_preservation to palaeontinidae;
grant all on niveaux_litho to palaeontinidae;
grant all on lithostrat to palaeontinidae;
grant all on localites to palaeontinidae;
grant all on types_preservation_index_seq to palaeontinidae;
grant all on lithostrat_index_seq to palaeontinidae;
grant all on niveaux_litho_index_seq to palaeontinidae;
grant all on localites_index_seq to palaeontinidae;
grant all on taxons_x_sites to palaeontinidae;
COMMIT;