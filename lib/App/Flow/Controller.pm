package App::Flow::Controller;
use utf8;
use strict;
use warnings;
use parent 'Plack::Component';

use Plack::Util::Accessor qw(config);


sub dbh_for {
  my ($self, $db_name) = @_;

  # get credentials from the YAML config file
  my $db_config = $self->config->{databases}{$db_name}
    or die "connect_db(): no config for database '$db_name'";
  my $connect_params = $db_config->{connect}
    or die "connect_db(): no config for '$db_name' has no 'connect' entry";

  # connect
  my $dbh = DBI->connect(@$connect_params)
    or die $DBI::errstr;

  return $dbh;
}


1;


