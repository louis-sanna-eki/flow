package HTML_func;

use Carp;
use strict;
use warnings;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use CGI::Pretty;

BEGIN {
	use Exporter   ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	
	#$VERSION     = 1.00;
	# le tout sur une seule ligne, pour MakeMaker
	#$VERSION = do { my @r = (q$Revisio: XXX $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };
	
	@ISA         = qw(Exporter);
	@EXPORT      = qw(&html_header &html_footer &arg_persist &chainUp &chainDown &getLastLink);
	%EXPORT_TAGS = ();
	
	# vos variables globales a etre exporter vont ici,
	# ainsi que vos fonctions, si nÃ©cessaire
	@EXPORT_OK   = qw();
}
    

# Les globales non exportees iront la 
use vars      qw(&html_header &html_footer  &arg_persist &chainUp &chainDown &getLastLink);

# Initialisation de globales, en premier, celles qui seront exportees
#$Variable
#%Hash = ();

# Toutes les lexicales doivent etre crees avant
# les fonctions qui les utilisent.

# les lexicales privees vont la

# Voici pour finir une fonction interne a ce fichier,
# Appelée par &$priv_func;  elle ne peut etre prototypee.
#my $priv_func = sub {}

# faites toutes vos fonctions, exportÃ© ou non;
# n'oubliez pas de mettre quelque chose entre les {}
#sub function     {}

# Builds a string witch contains html header
############################################################################################
sub html_header {
	my ($hash) = @_;

	my $html = header();
	
	$html .= start_html(-title  =>$hash->{'titre'},
			-author =>'angel_anta@hotmail.com',
			-base   =>'true',
			-style  =>{'-code'=>$hash->{'css'}},
			-head   =>meta({-http_equiv => 'Content-Type',
					-content    => 'text/html; charset=iso-8859-15'}),
			#-style  =>{'src'=>'/style.css'},
			#-TEXT   =>'#ffffff',
			-script =>$hash->{'jscript'},
			-BGCOLOR =>$hash->{'bgcolor'},
			-background =>$hash->{'background'},
			-onLoad =>$hash->{'onLoad'},
			-VLINK  =>'blue',
			-ALINK  =>'blue');
	
	return ($html);
}

# Builds a string witch contains html footer
############################################################################################
sub html_footer {
	my $html = '';
	#$html .= h5({-align=>'LEFT'},time2str("%d/%m/%Y-%X\n", time)); # Prints date
	$html .= end_html();
	return ($html);
}

# html form post arguments persistance
############################################################################################
sub arg_persist {

	my $hiddens;
	foreach (param()) {
		if (param($_)) { $hiddens .= hidden($_, param($_)); }
	}
	return $hiddens;
}


sub chainDown {

	my @urls = split(/->/,param('chain'));
	
	pop @urls;
	
	my $chain = join('->',@urls);
	
	return $chain;
}

sub chainUp {

	my ($url) = @_;
	
	my $chain;
	if (param('chain')) { 
		my @urls = split(/->/,param('chain'));
		
		$chain = param('chain');
		unless ($urls[$#urls] eq $url) { $chain .= "->$url"; }
	}
	else { $chain = $url; }
	
	return $chain;
}

sub getLastLink {
	
	my @urls = split(/->/,param('chain'));

	my $result;
	if (scalar(@urls)) { $result = $urls[$#urls]; }
	else { $result = "action.pl"; }

	return $result;	
}

END { }       # on met tout pour faire le menage ici (destructeurs globaux)

1;
