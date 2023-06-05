package App::Flow::Controller::SearchJs;
use utf8;
use strict;
use warnings;
use Text::Transliterator::Unaccent;
use JSON::XS;

use parent 'App::Flow::Controller';


# TODO : handle param "reload" at app level

sub call {
  my ($self, $env) = @_;

  # requête HTTP
  my $req   = Plack::Request->new($env);
  my $xlang = $req->param('lang') || 'en';

  # génération de la réponse -- contenu valide pendant 30 min.
  my $res = $req->new_response(200);
  $res->content_type('application/json; charset=UTF-8');
  $res->header(expire => time + 1800);

  # requêtes en base
  my $dbh = $self->dbh_for('flow');

  my $full_names = $dbh->selectall_arrayref(<<_EOSQL_);
     SELECT nc.index, nc.orthographe, 
            CASE WHEN (SELECT ordre FROM rangs WHERE index = nc.ref_rang) 
                    > (SELECT ordre FROM rangs WHERE en = 'genus') 
                 THEN nc.autorite 
                 ELSE coalesce(nc.autorite, '') || coalesce(' (' || 
                      (SELECT orthographe FROM noms WHERE index = 
                          (SELECT ref_nom_parent FROM noms WHERE index = nc.index)) 
                      || ')', '')
            END 
      FROM noms_complets AS nc 
      LEFT JOIN rangs AS r ON nc.ref_rang = r.index 
      WHERE r.en not in ('order', 'suborder') ORDER BY nc.orthographe
_EOSQL_

  my $authors = $dbh->selectall_arrayref(<<_EOSQL_);
     SELECT index, coalesce(nom || ' ', '') || coalesce(prenom, '') AS auteur from auteurs
_EOSQL_

  my $countries = $dbh->selectall_arrayref(<<_EOSQL_);
     SELECT index, $xlang from pays where index in (SELECT DISTINCT ref_pays FROM taxons_x_pays)
_EOSQL_

  # suppression des accents pour les auteurs et les pays
  my $unaccenter = Text::Transliterator::Unaccent->new;
  $unaccenter->($_->[1]) foreach @$authors, @$countries;


  # génération au format JSON
  my $json_coder = JSON::XS->new->utf8->pretty;
  my $mk_json = sub {
    my ($name, $rows) = @_;
    return "${name}ids=" . $json_coder->encode([map {$_->[0]} @$rows]) . ";\n"
         . "${name}="    . $json_coder->encode([map {$_->[1]} @$rows]) . ";\n"
  };
  my $json = $mk_json->(noms_complets => $full_names)
           . "authors=" . $json_coder->encode([map {$_->[2]} @$full_names]) . ";\n"
           . $mk_json->(auteurs       => $authors)
           . $mk_json->(pays          => $countries);

  # renvoi de la réponse
  $res->body($json);
  return $res->finalize;
}


1;
