use utf8;
use strict;
use warnings;
use FindBin qw/$Bin/;
use CGI::Compile;
use CGI::Emulate::PSGI;
use Plack::App::File;
use Plack::Builder;


$ENV{FLOW_CONFDIR} = "$Bin/etc";
$ENV{FLOW_SRCDIR}  = "$Bin/www";


my $cgi_script = "$Bin/www/cgi-bin/flow/flowsite.pl";
my $sub = CGI::Compile->compile($cgi_script);
my $cgi_app = CGI::Emulate::PSGI->handler($sub);

my $app = builder {
  mount "/flow" => $cgi_app;
  mount "/"    => Plack::App::File->new(root => "$Bin/www/html/Documents")->to_app;

};


# Allow this script to be run also directly (without 'plackup'), so that
# it can be launched from Emacs
unless (caller) {
  require Plack::Runner;
  my $runner = Plack::Runner->new;
  $runner->parse_options(-p => 5439, @ARGV);
  return $runner->run($app);
}


return $app;
