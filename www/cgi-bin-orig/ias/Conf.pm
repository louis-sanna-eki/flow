package Conf;

use Carp;
use strict;
use warnings;
use CGI qw( -no_xhtml :standard );
use CGI::Carp qw( fatalsToBrowser warningsToBrowser );

BEGIN {
	use Exporter   ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA         = qw(Exporter);
	@EXPORT      = qw($css $conf_file &html_header &html_footer &arg_persist);
	%EXPORT_TAGS = ();	
	@EXPORT_OK   = qw();
}
    

use vars qw($css $conf_file &html_header &html_footer &arg_persist);

# Configuration file path for database connection
our $conf_file = '/etc/flow/ias.conf';

# submit query in sql (return a two dimensions array ref)
sub request_tab_with_values {	
	my ($req, $values, $dbh, $dim) = @_;

	my $tab_ref = [];
	if ( my $sth = $dbh->prepare($req) ){
		if ( $sth->execute(@{$values}) ){
			if ($dim eq 1) {
				while ( my @row = $sth->fetchrow_array ) {
    					push(@{$tab_ref}, $row[0]);
  				}
			} else {
				$tab_ref = $sth->fetchall_arrayref;
			}
			$sth->finish();
		}
		else { die "Could'nt execute sql request: $DBI::errstr\n--$req--\n" }
	} else { die "Could'nt prepare sql request: $DBI::errstr\n" }

	return $tab_ref;
}

# stylesheet
our $css = " 
	body {
		margin: 0 0 1% 0;
		color: #666666;
		font-size: 14px;
		font-family: Arial;
		background: #FDFDFD;
	}
	
	FIELDSET { background: #C2C2C2; border: 1px #C2C2C2 solid; }
	FIELDSET LEGEND { background: #C2C2C2; color: #444444; padding: 2px 10px 0 10px; }
	INPUT, TEXTAREA { border: 1px solid #BBBBBB; padding: 0 2px; color: navy; font-family: Arial; font-size: 14px; }
	SELECT { border: 1px solid #BBBBBB; padding-left: 5px; color: navy; }
	
	.fieldset1 { border: 1px #D0D0D0 solid; background: #D0D0D0; }
	.fieldset2 { border: 1px transparent solid; background: transparent; padding: 6px 6px 0px 6px; }
	.fieldset1 legend { background: #D0D0D0; color: #666666; }
	.fieldset2 legend { background: transparent; color: #666666; }
	.fieldset1 .fieldset2 .fieldset1 { background: transparent; border-top: 1px #888888 solid; border-left: 1px #888888 solid; border-right: 0px #888888 solid; border-bottom: 0px #888888 solid; padding: 6px 6px 0px 6px; }
	.fieldset1 .fieldset2 .fieldset1 legend { background: transparent; color: #666666;  padding-left: 6px; padding-top: 0px; }
	.fieldset1 .fieldset2 .fieldset1 .fieldset2 { background: transparent; border: 0px #888888 solid; padding: 6px 6px 0px 0px; }
	.fieldset1 .fieldset2 .fieldset1 .fieldset2 legend { background: transparent; color: #666666; padding-left: 2px; padding-top: 0px; }
	.padding0 { padding-left: 0px; }
	
	.fieldset1 .pagep { margin-left: 10px; }
	.fieldset1 .fieldset2 .pagep { margin-left: 2px; }
	
	.round {
		-moz-border-radius: 6px;
		-webkit-border-radius: 6px;
		border-radius: 6px;
	}
	
	.wcenter {
		width: 900px;
		min-width: 900px;
		margin: 0 auto;
	}
	
	.PopupStyle {
		/*background: #FFFFFF;
		color: #222222;
		font-family: Arial;
		font-size: 12pt;*/
	}

	.popupTitle {
		background: #FFFFFF;
		color: #222222;
		font-weight: bold;
		font-family: Arial;
	}
		
	.autocomplete {
	    background: #FDFDFD;
	    cursor: default;
	    overflow: auto;
	    overflow-x: hidden;
	    border: 1px solid #222222;
	    font-size: 14px;
	}
	
	.autocomplete_item {
	    padding: 1px;
	    padding-left: 5px;
	    color: navy;
	}
	
	.autocomplete_item_highlighted {
	    padding: 1px;
	    padding-left: 5px;
	    color: crimson;
	}
	
	.buttonSubmit { border: none; background: url('/Editor/submit.png') no-repeat top left; height: 22px; width: 78px; color: transparent; }
	.buttonClear { border: none; background: url('/Editor/clear.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonHome { border: none; background: url('/Editor/home.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonBack { border: none; background: url('/Editor/back.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonNew { border: none; background: url('/Editor/new.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonModify { border: none; background: url('/Editor/modify.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonInsert { border: none; background: url('/Editor/insert.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonUpdate { border: none; background: url('/Editor/update.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonDelete { border: none; background: url('/Editor/delete.png') no-repeat top left; height: 25px; width: 22px; color: transparent; }
";

##########################################################################################################################################################
#		HTML building functions				##########################################################################################
##########################################################################################################################################################

# Builds a string witch contains html header
############################################################################################
sub html_header {
	my ($hash) = @_;

	my $html = header({-Type=>'text/html', -Charset=>'UTF-8'});
	
	$html .= start_html(-title  =>$hash->{'titre'},
			-author =>'angel_anta@hotmail.com',
			-base   =>'true',
			-style  =>{'-code'=>$hash->{'css'}},
			-head   =>meta({-http_equiv => 'Content-Type', -content => 'text/html; charset=UTF-8'}),
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

1;
