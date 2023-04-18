#!/usr/bin/perl

use strict;
#use warnings;
use DBI;
use CGI qw( -no_xhtml :standard start_ul); # make html 4.0 card
use CGI::Carp qw( fatalsToBrowser ); # display errors in browser
use Getopt::Long;
use utf8;
use open ':std', ':encoding(UTF-8)';
#no warnings 'experimental::smartmatch';

#BEGIN { binmode(STDOUT, ':encoding(UTF-8)'); }  # HTML
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';  # Error log
binmode STDIN, ":encoding(UTF-8)";
#use Encode;

# $Id: traduction.pl,v 1.1 2007/01/26 13:10:06 gallut Exp $
#use HTML::Entities;

use CGI qw( -no_xhtml :standard start_ul); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browseruse CGI::Pretty;
use Date::Format;
use DBCommands qw (get_connection_params read_lang db_connection request_hash request_tab request_row);


# Gets config
################################################################

my $config_file = '/etc/flow/translatedbutf8.conf';
# read config file
my $config = { };
if ( open(CONFIG, $config_file) ) {
	while (<CONFIG>) {
		chomp;                 # no newline
		s/#.*//;               # no comments
		s/^\s+//;              # no leading white
		s/\s+$//;              # no trailing white
		next unless length;    # anything left?
		my ($option, $value) = split(/\s*=\s*/, $_, 2);
		$config->{$option} = $value;
	}

	close(CONFIG);
}
else {
	die "No configuration file could be found\n";
}


# Gets parameters
################################################################
my $id   = url_param('id'); # Gets id


# Main
################################################################
if ( param("new") ){ new_token() }
elsif ( param("id_change") ){ change_token() }
elsif ( param("modify") ){ modify_token() }
elsif ( param("create") ){ create_token() }
elsif ( param("home") ){ token_list() }
else { token_list() }
exit;


# Modify a token in the database
#################################################################
sub modify_token {

	if ( my $dbc = db_connection($config) ) { # connection

		my $user = remote_user();
		my $id_old = param("id_old");
		my $id = param("id");
		my $en = param("en");
		my $zh = param("zh");
		my $fr = param("fr");
		my $es = param("es");
		my $pt = param("pt");
		my $de = param("de");

		utf8::decode($en);
		utf8::decode($zh);
		utf8::decode($fr);
		utf8::decode($es);
		utf8::decode($pt);
		utf8::decode($de);

		my $sth = $dbc->prepare( "UPDATE traductions SET id = ?, en = ?, fr = ?, es = ?, pt = ?, de = ?, zh = ?, modificateur = ?, date_modification = current_date WHERE id = ?;" );

		$sth->execute(($id,$en,$fr,$es,$pt,$de,$zh,$user,$id_old)) ;

		# build html

		print html_header("Entry modified"), # header
			h1(" Entry modified"), #title
			"You have modified:",
			br(),br(),
			table( Tr( td( [ qw( Identificator English Chinese Français Español Português Deutsch ) ] ) ),
			Tr( td( [ $id, $en, $zh, $fr, $es, $pt, $de ] ) ) ),
			start_form(),
			br(),br(),
			submit("new"),
			submit("home"),
			input({-type=>'submit',-name=>'id_change',-value=>"$id"}),
			end_form(),
			html_footer();

		$dbc->disconnect; # disconnection
	}
	else { } # Connection failed
}

# Modifying a token
#################################################################

sub change_token {
	if ( my $dbc = db_connection($config) ) { # connection
		my $user = remote_user();
		my $id = param("id_change");
		my $request = "SELECT en, fr, es, pt, de, zh, createur, date_creation, modificateur, date_modification FROM traductions WHERE id = '$id';";
		my $token = request_row($request, $dbc);
		# build html

		print html_header("Entry modification"), # header
			h1("Entry modification"), #title
			start_form('post'),
			table( Tr( td( [ qw( Identificator English Chinese Français Español Português Deutsch ) ] ) ),
			Tr( td( [ input( {-type=>'text',-name=>'id',-value=>"$id"} ),
				textarea( {-cols=>'25',-rows=>'25',-name=>'en',-value=>$token->[0]} ),
				textarea( {-cols=>'25',-rows=>'25',-name=>'zh',-value=>$token->[5] || $token->[0]} ),
				textarea( {-cols=>'25',-rows=>'25',-name=>'fr',-value=>$token->[1] || $token->[0]} ),
				textarea( {-cols=>'25',-rows=>'25',-name=>'es',-value=>$token->[2] || $token->[0]} ),
				textarea( {-cols=>'25',-rows=>'25',-name=>'pt',-value=>$token->[3] || $token->[0]} ),
				textarea( {-cols=>'25',-rows=>'25',-name=>'de',-value=>$token->[4] || $token->[0]} )
				] ) ),
			caption( {-align=>'bottom',-style=>'font-size: small'}, "Created by $token->[5], $token->[6]. Modified by $token->[7], $token->[8]"  )),
			input( {-type=>'hidden',-name=>'id_old',-value=>"$id"} ),
			br(),br(),
			submit("modify"),
			submit("home"),
			end_form(),
			html_footer();

		$dbc->disconnect; # disconnection
	}
	else { } # Connection failed
}

# Create a new token in the database
#################################################################
sub create_token {
	if ( my $dbc = db_connection($config) ) { # connection

		my $user = remote_user();
		my $id = param("id");
		my $en = param("en");
		my $fr = param("fr");
		my $es = param("es");
		my $pt = param("pt");
		my $de = param("de");
		my $zh = param("zh");

        utf8::decode($en);
        utf8::decode($zh);
        utf8::decode($fr);
        utf8::decode($es);
        utf8::decode($pt);
        utf8::decode($de);

		my $sth = $dbc->prepare( "INSERT INTO traductions ( id, en, fr, es, pt, de, zh, createur, modificateur ) VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ? );" );

		$sth->execute(( $id, to_uft8($en), to_uft8($fr), to_uft8($es), to_uft8($pt), to_uft8($de), to_uft8($zh),$user, $user ) ) or die "$DBI::errstr : $id, $en, $fr, $es, $pt, $de, $zh, $user, $user";

		# build html

		print html_header("New entry"), # header
			h1("New entry:"), #title
			"You have entered:",
			br(),br(),
			table( Tr( td( [ qw( Identificator English Chinese Français Español Português Deutsch ) ] ) ),
			Tr( td( [ $id, $en, $zh, $fr, $es, $pt, $de  ] ) ) ),
			start_form(),
			br(),br(),
			submit("new"),
			submit("home"),
			end_form(),
	html_footer();

		$dbc->disconnect; # disconnection
	}
	else { } # Connection failed
}

# New token
#################################################################
sub new_token {
	# build html

	print html_header("Create a new entry"), # header
		h1("Create a new entry"), #title
		start_form(),
		table( Tr( td( [ qw( Identificator English Chinese Français Español Português Deutsch ) ] ) ),
		Tr( td( [
				input( {-type=>'text',-name=>'id'} ),
				input( {-type=>'text',-name=>'en'} ),
				input( {-type=>'text',-name=>'zh'} ),
				input( {-type=>'text',-name=>'fr'} ),
				input( {-type=>'text',-name=>'es'} ),
				input( {-type=>'text',-name=>'pt'} ),
				input( {-type=>'text',-name=>'de'} )
				] ) ) ),
		br(),br(),
		submit("create"),
		submit("home"),
		end_form(),
		html_footer();
}

# Token list
#################################################################
sub token_list {
	if ( my $dbc = db_connection($config) ) { # connection

		# Get Tokens list
		my $tokens = request_tab("SELECT id, en, zh, fr, es, pt, de FROM traductions ORDER BY LOWER ( en );",$dbc);

		# build html

		print html_header("Names to be translated"), # header
			h1("Names to be translated:"), #title
			start_form(),
			submit("new"),
			br(),br(),
			table(map { Tr( {-type=>'disc'}, td( [ input(  {-type=>'submit',-name=>'id_change',-value=>"$_->[0]"} ), $_->[0], $_->[1], $_->[2], $_->[3], $_->[4], $_->[5] ] ) ) } @{$tokens}),
			end_form(),
			html_footer();

		$dbc->disconnect; # disconnection
	}
	else { } # Connection failed
}

# Builds a string witch contains html header
############################################################################################
sub html_header {
	my ($title) = @_;
    #iso-8859-1
	my $html .= header({-Type=>'text/html', -Charset=>'UTF-8'});
	$html .= start_html(-title  =>$title,
			-author =>'cyril.gallut@upmc.fr',
			-base   =>'true',
			-head   =>meta({-http_equiv => 'Content-Type',
					-content    => 'text/html; charset=UTF-8'}),
			-meta   =>{'keywords'   =>'FLOW,fulgores,editeur',
				'description'=>'flow editor menu'},
			-style  =>{'src'=>'/style.css'});
	return ($html);
}

# Builds a string witch contains html footer
############################################################################################
sub html_footer {
	my $html = br();
	$html .= hr;
	$html .= h5({-align=>'RIGHT'},time2str("%d/%m/%Y-%X\n", time)); # Prints date
	$html .= big(font({-color=>'#FF0000'},"Under construction"));
	$html .= end_html();
	return ($html);
}

