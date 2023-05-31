use utf8;
use strict;
use warnings;

use CGI::Compile;
use CGI::Emulate::PSGI;

$ENV{FLOW_CONFDIR} = "d:/Git/DAMI/flow/etc";
$ENV{FLOW_SRCDIR}  = "d:/Git/DAMI/flow/www";


my $cgi_script = "cgi-bin/flow/flowsite.pl";
use lib "cgi-bin/flow";
my $sub = CGI::Compile->compile($cgi_script);
my $app = CGI::Emulate::PSGI->handler($sub);


# Allow this script to be run also directly (without 'plackup'), so that
# it can be launched from Emacs
unless (caller) {
  require Plack::Runner;
  my $runner = Plack::Runner->new;
  $runner->parse_options(-p => 5439, @ARGV);
  return $runner->run($app);
}


return $app;

