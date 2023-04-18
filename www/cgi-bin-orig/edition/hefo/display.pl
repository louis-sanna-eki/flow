#!/usr/bin/perl
BEGIN {push @INC, '/var/www/cgi-bin/edition/hefo/'} 
use strict;
use warnings;
use diagnostics;
use CGI qw( -no_xhtml :standard );
use CGI::Carp qw( fatalsToBrowser warningsToBrowser );
use DBCommands qw(get_connection_params db_connection request_tab request_row request_hash);
use Conf qw ($conf_file $css html_header html_footer arg_persist);

my $dbc = db_connection(get_connection_params($conf_file));

my $action = url_param('action');

my %headerHash = (
	titre => "DBTNT explorer configuration",
	css => 'body { background: #EEEEEE; font-family: Arial; }'
);

my %labels = (
	'descent' => 'children&nbsp;taxa',
	'map' => 'distribution&nbsp;map',
	'tdwg' => 'distribution&nbsp;list',
	'vernaculars' => 'common&nbsp;names',
	'misspellings_corrections' => 'misspellings&nbsp;corrections',
	'princeps' => 'described&nbsp;taxa',
	'geological' => 'geological dating'
);

my $borderStyle = "-moz-border-radius: 10px; -webkit-border-radius: 10px; border-radius: 10px;";

my ( $card, $element, $skip, $display, $position, $attributes, $prevelem );
my $body;

my %card_labels = (
	'families' => 'families list',
	'genera' => 'genera list',
	'speciess' => 'species list',
	'names' => 'species list'
);

if ($action eq 'modify') {
	
	my $sth = $dbc->prepare( "SELECT card, element, skip, display, position, attributes FROM display_modes ORDER BY card, position, element;" );
	$sth->execute( );
	$sth->bind_columns( \( $card, $element, $skip, $display, $position, $attributes ) );
	
	my $current;
	my $i = 0;
	while ( $sth->fetch() ){
	
		my $card_label = $card_labels{$card} || "$card card";
		my $elemlabel = $labels{$element} ?  $labels{$element} : $element;
		
		unless ($current) {
			$current = $card;
			$body .= "<TABLE STYLE='border: 1px solid darkgrey; $borderStyle'><TR><TD COLSPAN=5 STYLE='padding: 6px; text-align: center; color: crimson; font-weight: bold; border-bottom: 1px solid darkgrey;'>$card_label</TD></TR>"; 
			if ($element ne 'list') {
				$body .= "<TR><TD STYLE='text-align: center; font-size: 14px; color: navy; padding: 6px; border-bottom: 0px solid darkgrey;'>element</TD>".
					 "<TD STYLE='text-align: center; font-size: 14px; color: navy; padding: 6px; border-bottom: 0px solid darkgrey;'>display&nbsp;element</TD>".
					 "<TD STYLE='text-align: center; font-size: 14px; color: navy; padding: 6px; border-bottom: 0px solid darkgrey;'>fully&nbsp;display</TD>".
					 "<TD STYLE='text-align: center; font-size: 14px; color: navy; padding: 6px; border-bottom: 0px solid darkgrey;'>position</TD>";
			}
			$body .= "<TD STYLE='text-align: center; font-size: 14px; color: navy; padding: 6px; border-bottom: 0px solid darkgrey;'>attributes</TD></TR>"; 
		}
		elsif ($card ne $current) {
			$current = $card;
			$body .= "</TABLE>";
			$body .= p . submit('OK') . p;
			$body .= "<TABLE STYLE='border: 1px solid darkgrey; $borderStyle'><TR><TD COLSPAN=5 STYLE='padding: 6px; text-align: center; color: crimson; font-weight: bold; border-bottom: 1px solid darkgrey;'>$card_label</TD></TR>"; 
			if ($element ne 'list') {
				$body .= "<TR><TD STYLE='text-align: center; font-size: 14px; color: navy; padding: 6px; border-bottom: 0px solid darkgrey;'>element</TD>".
				 	"<TD STYLE='text-align: center; font-size: 14px; color: navy; padding: 6px; border-bottom: 0px solid darkgrey;'>display&nbsp;element</TD>".
				 	"<TD STYLE='text-align: center; font-size: 14px; color: navy; padding: 6px; border-bottom: 0px solid darkgrey;'>fully&nbsp;display</TD>".
				 	"<TD STYLE='text-align: center; font-size: 14px; color: navy; padding: 6px; border-bottom: 0px solid darkgrey;'>position</TD>";
			}	 
			$body .= "<TD STYLE='text-align: center; font-size: 14px; color: navy; padding: 6px; border-bottom: 0px solid darkgrey;'>attributes</TD></TR>"; 
		}
		$body .= hidden("card$i", $card);
		$body .= hidden("previous_element$i", $element);
		$body .= "<TR>";
		if ($element ne 'list') {
			
			$body .= "<TD STYLE='text-align: center; padding: 0 6px; font-size: 12px;'>$elemlabel</TD>";
		
			$body .= "<TD STYLE='text-align: center;'>";
			$body .= "<SELECT NAME=skip$i>";
			if ($skip) {
				$body .= "<OPTION VALUE='false'>yes";
				$body .= "<OPTION VALUE='true' SELECTED>no";
			}
			else {
				$body .= "<OPTION VALUE='false' SELECTED>yes";
				$body .= "<OPTION VALUE='true'>no";
			}
			$body .= "</SELECT>";
			$body .= "</TD>";
			
			$body .= "<TD STYLE='text-align: center;'>";
			$body .= "<SELECT NAME=display$i>";
			if ($display) {
				$body .= "<OPTION VALUE='false'>no";
				$body .= "<OPTION VALUE='true' SELECTED>yes";
			}
			else {
				$body .= "<OPTION VALUE='false' SELECTED>no";
				$body .= "<OPTION VALUE='true'>yes";
			}
			$body .= "</SELECT>";
			$body .= "</TD>";
			
			$body .= "<TD STYLE='text-align: center;'>";
			if ( $position == -1 ) {
				$body .= hidden("position$i", -1);
			}
			else {
				$body .= textfield(-name=>"position$i", -default=>$position, size=>2, -style=>'font-size: 12px;');
			}
			$body .= "</TD>";
		}
		
		$body .= "<TD>";
		$body .= 	textfield(-name=>"attributes$i", -default=>$attributes, size=>80, -style=>'font-size: 12px;');
		$body .= "</TD>";
		$body .= "</TR>";
		$i++;
	}
	$body .= "</TABLE>";
	$body .= p . submit('OK');
	
	print 	html_header(\%headerHash),
			div ({-style=>'margin: 2% auto; width: 1000px;'},
				div({-style=>"font-size: 18px; color: darkgreen; margin: 0 auto; width: 400px;"}, "DBTNT explorer configuration"), p,
				start_form(-name=>'Form', -method=>'post',-action=>url().'?action=update'),
					$body,
				end_form()	
			),
			html_footer();
}
elsif ($action eq 'update') {
	my $test;
	my $i = 0;
	my $req = "BEGIN; ";
	while ($card = param("card$i")) {
		$skip = param("skip$i") || 'null';
		$display = param("display$i") || 'null';
		$position = param("position$i") || 'null';
		$attributes = param("attributes$i");
		$prevelem = param("previous_element$i");
		$element = param("element$i") || $prevelem;
				
		if ($prevelem) {
			$req .= "UPDATE display_modes SET skip = $skip, display = $display, position = $position, attributes = '$attributes' WHERE card = '$card' AND element = '$prevelem'; ";
		}
		else {
			$req .= "DELETE FROM display_modes WHERE card = '$card' AND element = '$prevelem'; ";
		}
		
		$i++;
	}
	$req .= "COMMIT;";
		
	my $sth = $dbc->prepare( $req );
	$sth->execute( );
	
	print 	html_header(\%headerHash),
		div ({-style=>'margin: 2% auto; width: 1000px;'},
			img({-border=>0, -src=>'/Editor/done.png', -name=>"done" , -alt=>"DONE"}), p,
			"Modification done", p,
			a({-href=>url()."?action=modify", -style=>'text-decoration: none;'}, "Modify explorer configuration"), p,
			a({-href=>url()."?action=add", -style=>'text-decoration: none;'}, "Add new element of explorer configuration"), p,
			$test
		),
		html_footer();
}
elsif ($action eq 'add') {
	
	my $i = 0;
	$body .= "<TABLE STYLE='border: 1px solid darkgrey; $borderStyle'>"; 
	$body .= "<TR>".
		"<TD STYLE='text-align: center; font-size: 14px; color: navy; padding: 6px;'>card</TD>".
		"<TD STYLE='text-align: center; font-size: 14px; color: navy; padding: 6px;'>element</TD>".
		"<TD STYLE='text-align: center; font-size: 14px; color: navy; padding: 6px;'>skip&nbsp;element</TD>".
		"<TD STYLE='text-align: center; font-size: 14px; color: navy; padding: 6px;'>fully&nbsp;display</TD>".
		"<TD STYLE='text-align: center; font-size: 14px; color: navy; padding: 6px;'>attributes</TD>".
		"</TR>"; 
	
	while ( $i<11 ){		
		$body .= "<TR><TD>";
		$body .= textfield(-name=>"card$i", size=>12);
		$body .= "</TD><TD>";
		$body .= textfield(-name=>"element$i", size=>26);
		$body .= "</TD><TD STYLE='text-align: center;'>";
		$body .= "<SELECT NAME=skip$i>";
		$body .= "<OPTION VALUE='false' SELECTED>no";
		$body .= "<OPTION VALUE='true'>yes";
		$body .= "</SELECT>";
		$body .= "</TD><TD STYLE='text-align: center;'>";
		$body .= "<SELECT NAME=display$i>";
		$body .= "<OPTION VALUE='false' SELECTED>no";
		$body .= "<OPTION VALUE='true'>yes";
		$body .= "</SELECT>";
		$body .= "</TD><TD STYLE='text-align: center;'>";
		$body .= textfield(-name=>"position$i", size=>2, -style=>'font-size: 12px;');
		$body .= "</TD><TD>";
		$body .= textfield(-name=>"attributes$i", size=>80, -style=>'font-size: 12px;');
		$body .= "</TD></TR>";
		$i++;
	}
	$body .= "</TABLE>";
	$body .= p . submit('OK');
	
	print 	html_header(\%headerHash),
			div ({-style=>'margin: 2% auto; width: 1000px;'},
				div({-style=>"font-size: 18px; color: darkgreen; margin: 0 auto; width: 400px;"}, "DBTNT explorer configuration"), p,
				start_form(-name=>'Form', -method=>'post',-action=>url().'?action=insert'),
					$body,
				end_form()	
			),
			html_footer();
}
elsif ($action eq 'insert') {
	
	my $i = 0;
	my $req = "BEGIN; ";
	while ($card = param("card$i")) {
		$element = param("element$i");
		$skip = param("skip$i");
		$display = param("display$i");
		$position = param("position$i");
		$attributes = param("attributes$i");
		$prevelem = param("previous_element$i");
		
		if ($card and $element) {	
			$req .= "INSERT INTO display_modes (card, element, skip, display, position, attributes) VALUES ('$card', '$element', $skip, $display, $position, '$attributes'); ";
		}		
		$i++;
	}
	$req .= "COMMIT;";
	
	my $sth = $dbc->prepare( $req );
	$sth->execute( );
	
	print 	html_header(\%headerHash),
		div ({-style=>'margin: 2% auto; width: 1000px;'},
			img({-border=>0, -src=>'/Editor/done.png', -name=>"done" , -alt=>"DONE"}), p,
			"Elements added", p,
			a({-href=>url()."?action=modify", -style=>'text-decoration: none;'}, "Modify explorer configuration"), p,
			a({-href=>url()."?action=add", -style=>'text-decoration: none;'}, "Add new element of explorer configuration")
			
		),
		html_footer();
}	

