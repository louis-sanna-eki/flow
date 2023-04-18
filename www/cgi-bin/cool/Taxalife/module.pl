#!/usr/bin/perl 

use strict;
use CGI qw (-no_xhtml :standard);
use CGI::Carp qw (fatalsToBrowser warningsToBrowser);

my $css = " 
	.col3 {
		color:red;
	}
	
";
																				
print header();

print start_html (
	-style  =>{'-code'=>$css},
	
					),
	
	
print div ({-class=>"col3"},"
	<html>
	<head>
	 <title>bonjour</title>
	</head>
	<frameset rows='50%,50%' border='1'>
	    <frame  name='top' src = 'entete.pl'>
		<frame  name='bottom'   scrolling='auto' bordercolor='red'>
	</frameset>

	<body>
	<noframes>
	<center>
	Votre navigateur ne supporte pas les frames (cadres)<br>
	Téléchargez en une version récente pour pouvoir profiter de ce site !<br>
	<br>
	Your browser doesn't support frames.<br>
	Please get a newer one to be able to view this site.<br>
	</center>
	</noframes>
	</body>
	</html>")

