#!/usr/bin/perl

use strict;
use warnings;
use diagnostics;
use CGI qw( -no_xhtml :standard );
use CGI::Carp qw( fatalsToBrowser warningsToBrowser );
use DBCommands qw(get_connection_params db_connection request_tab request_row request_hash);
use Conf qw ($conf_file $css html_header html_footer arg_persist);

my $dbc = db_connection(get_connection_params($conf_file));

my $action = url_param('action');

my $validate = 	"function validateForm() {
		var x;
		var y;
		x = document.Form.firstname.value;
		if (x == null || x == '') {
			alert('First name must be filled out');
			return false;
		}
		x = document.Form.lastname.value;
		if (x == null || x == '') {
			alert('Last name must be filled out');
			return false;
		}
		x = document.Form.email.value;
		if (x == null || x == '') {
			alert('Email must be filled out');
			return false;
		}
		x = document.Form.recommends1.value;
		y = document.Form.recommends2.value;
		if (x == null || x == '' || y == null || y == '') {
			x = document.Form.authors1.value;
			if (x == null || x == '') {
				alert('Unless you are recommended by two IAS members, all publication fields must be filled out');
				return false;
			}
			x = document.Form.year1.value;
			if (x == null || x == '' || isNaN(x)) {
				alert('Unless you are recommended by two IAS members, all publication fields must be filled out, and years must be numeric');
				return false;
			}
			x = document.Form.title1.value;
			if (x == null || x == '') {
				alert('Unless you are recommended by two IAS members, all publication fields must be filled out');
				return false;
			}
			x = document.Form.references1.value;
			if (x == null || x == '') {
				alert('Unless you are recommended by two IAS members, all publication fields must be filled out');
				return false;
			}
			x = document.Form.authors2.value;
			if (x == null || x == '') {
				alert('Unless you are recommended by two IAS members, all publication fields must be filled out');
				return false;
			}
			x = document.Form.year2.value;
			if (x == null || x == '' || isNaN(x)) {
				alert('Unless you are recommended by two IAS members, all publication fields must be filled out, and years must be numeric');
				return false;
			}
			x = document.Form.title2.value;
			if (x == null || x == '') {
				alert('Unless you are recommended by two IAS members, all publication fields must be filled out');
				return false;
			}
			x = document.Form.references2.value;
			if (x == null || x == '') {
				alert('Unless you are recommended by two IAS members, all publication fields must be filled out');
				return false;
			}
		}
	}";
		
my %headerHash = (
	titre => "IAS website",
	css => 'body { background: #CAE2E2; font-family: Arial; font-size: 14px; } .finput { background: #E4F1F1; border: 0; }',
	head => meta({-http_equiv => 'Pragma', -content => 'no-cache'})
);

my $borderStyle = "-moz-border-radius: 10px; -webkit-border-radius: 10px; border-radius: 10px;";


my $home;
if ($action) { $home = td({-style=>'padding: 10px 0 0 10px;'}, a({-href=>'http://hemiptera.infosyslab.fr/ias'}, img({-border=>0, -src=>'/ias/Home_Icon.png', -name=>"home" , -alt=>"IAS home", -width=>'30px'})));  }
my $bandeau = table({-style=>'margin: 0 auto;', -border=>0}, Tr(
					td(a({-href=>'http://hemiptera.infosyslab.fr/ias'}, img({-border=>0, -src=>'/ias/ias_logo.png', -name=>"logo" , -alt=>"IAS logo", -width=>'100px'}))), 
					td({-style=>'padding: 10px 50px 0 50px;'}, span({-style=>"font-size: 28px;"}, "International Auchenorrhyncha Society")),
					$home
				)). p;

my $aims = "IAS will act as a global forum for the exchange of information about Insecta Hemiptera Auchenorrhyncha and will facilitate activities in support of its objectives. IAS has the objectives:". br.
	"1) To promote scientific fundamental and applied biological research on extant and extinct insects of the Hemiptera Auchenorrhyncha particularly in Systematics, Biogeography and Etho-Ecology;". br.
	"2) To promote access to any kind of information about Auchenorrhyncha including the collections and through databases, publication and educational activities;". br.
	"3) To promote cooperative research among Auchenorrhyncha workers throughout the world to enable the formation of partnerships for collaborative actions and projects.". p;


my $menus = 	td({-rowspan=>2},
		
		"- Join IAS: " . a({-href=>'http://hemiptera.infosyslab.fr/ias?action=register'}, "membership registration") . p.
		
		"- IAS statutes (soon available)". p.
		
		"- IAS committees:". p.
		span({-style=>'margin-left: 10px;'}, "> Executive committee"). p.
		span({-style=>'margin-left: 30px;'}, "Thierry Bourgoin: ".b("Chair")). br.
		span({-style=>'margin-left: 30px;'}, "Mike Wilson: ".b("Vice-chair")). br.
		span({-style=>'margin-left: 30px;'}, "Murray Fletcher: ".b("Past chair")). br.
		span({-style=>'margin-left: 30px;'}, "Werner Holzinger: ".b("General secretary")). br.
		span({-style=>'margin-left: 30px;'}, "Jacek Szwedo: ".b("Treasurer")).' <a href="mailto:szwedo@miiz.waw.pl" target="_top">contact</a>'. p.
        	
		span({-style=>'margin-left: 10px;'}, "> Board of administrators"). p.
		span({-style=>'margin-left: 30px;'}, 'Thierry Bourgoin (bourgoin@mnhn.fr) France'). br.
		span({-style=>'margin-left: 30px;'}, 'Chris Dietrich (dietrich@inhs.uiuc.edu) USA'). br.
		span({-style=>'margin-left: 30px;'}, 'Murray Fletcher (murray.fletcher@dpi.nsw.gov.au) Australia'). br.
		span({-style=>'margin-left: 30px;'}, 'Vladimir Gnezdilov (vmgnezdilov@mail.ru)	Russia'). br.
		span({-style=>'margin-left: 30px;'}, 'Masami Hayashi (mh@sci.edu.saitama-u.ac.jp) Japan'). br.
		span({-style=>'margin-left: 30px;'}, 'Hannelore Hoch (Hannelore Hoch <hannelore.hoch@mfn-berlin.de>) Germany'). br.
		span({-style=>'margin-left: 30px;'}, 'Werner Holzinger (holzinger@oekoteam.at)	Austria'). br.
		span({-style=>'margin-left: 30px;'}, 'Yong Jung Kwon (yjkwon@bh.kyungpook.ac.kr)	Korea'). br.
		span({-style=>'margin-left: 30px;'}, 'Gabriel Mejdalani (mejdalan@acd.ufrj.br)	Brazil'). br.
		span({-style=>'margin-left: 30px;'}, 'Sofia Seabra (sgseabra@fc.ul.pt) Portugal'). br.
		span({-style=>'margin-left: 30px;'}, 'Jacek Szwedo (Jacek Szwedo <szwedo@miiz.waw.pl>) 	Poland'). br.
		span({-style=>'margin-left: 30px;'}, 'Mike Stiller (StillerM@arc.agric.za)	South Africa'). br.
		span({-style=>'margin-left: 30px;'}, 'Mike Wilson (mike.wilson@museumwales.ac.uk	UK'). br.
		span({-style=>'margin-left: 30px;'}, 'Zhang Yalin (yalinzh@yahoo.com.cn)	China'). br.
		span({-style=>'margin-left: 30px;'}, 'Zhu Zeng-Rong (zrzhu@zju.edu.cn)	China'). p
        );

my $msg;
if ($action eq 'insert') { $msg = span({-style=>'color: crimson;'}, "Thank you for registering."). p; }

my $encart = 	td({-style=>'font-size: 16px; color: darkgreen; vertical-align: top; padding-top: 40px;'},
			
			span({-style=>'font-weight: bold;'}, "IAS, Promoting Auchenorrhyncha Knowledge."). p.
				
			$msg.
	
			"1st International Auchenorrhyncha Society Annual General Meeting (AGM), ".
			"will be held on the 10th of July". br.
			"during the 14th International Auchenorrhyncha Congress & ".
			"the 8th International Workshop on Leafhoppers ". br. 
			"and Planthoppers of Economic Significance, 7-12 July 2013, Yangling, Shaanxi, China.". br.
			"All members are warmly invited to attend this important event and to invite guests or colleagues from the congress.". br
		);

my $more =      td({-style=>'padding-left: 50px;'},
			"- IAS contact:". p.
			span({-style=>'margin-left: 10px;'}, "IAS - MNHN-Entomologie"). br.
			span({-style=>'margin-left: 10px;'}, "CP50, 57 rue Cuvier"). br.
			span({-style=>'margin-left: 10px;'}, "75005 Paris, France"). p.
			"- past meetings (soon available)". br.
			"- current literature (soon available)". br.
			"- Auchenorrhyncha bibliography database (soon available)". br.
			"- other web resources on Auchenorrhyncha (soon available)". br
		);

unless ($action) {
	print 	html_header(\%headerHash),
			div ({-style=>"margin: 1% auto; width: 1250px; border: 0px solid black;"},
				$bandeau,
				$aims,
				table({-border=>0}, Tr($menus, $encart), Tr($more))
			),
			html_footer();
}
elsif ($action eq 'display') {
	my $req =  	"SELECT index, firstname, middlename, lastname, email, institution, city, (select name from countries where index = country),
			(select authors || ' ' || coalesce(year) || ' - ' || coalesce(title) || ', ' || coalesce(pubreferences) from publications where index = ref_pub1),
			(select authors || ' ' || coalesce(year) || ' - ' || coalesce(title) || ', ' || coalesce(pubreferences) from publications where index = ref_pub2),
			recommends1, recommends2,
			regdate,
			validdate 
			FROM members
			ORDER BY validdate DESC, regdate DESC;";
	
	my $cards = request_tab($req, $dbc, 2);
	my $inities;
	my $profanes;
	foreach (@{$cards}) { 
		if ($_->[13]) {
			$inities .= "<div style='border: 1px solid darkgrey; padding: 5px;'>";
			if ($_->[1]) { $inities .= "<span style='font-weight: bold;'>First name:</span> $_->[1]". br; }
			if ($_->[2]) { $inities .= "<span style='font-weight: bold;'>Middle name:</span> $_->[2]". br; }
			if ($_->[3]) { $inities .= "<span style='font-weight: bold;'>Last name:</span> $_->[3]". br; }
			if ($_->[4]) { $inities .= "<span style='font-weight: bold;'>Email:</span> $_->[4]". br; }
			if ($_->[5]) { $inities .= "<span style='font-weight: bold;'>Institution:</span> $_->[5]". br; }
			if ($_->[6]) { $inities .= "<span style='font-weight: bold;'>City:</span> $_->[6]". br; }
			if ($_->[7]) { $inities .= "<span style='font-weight: bold;'>Country:</span> $_->[7]". br; }
			if ($_->[8]) { $inities .= "<span style='font-weight: bold;'>publication:</span> $_->[8]". br; }
			if ($_->[9]) { $inities .= "<span style='font-weight: bold;'>publication:</span> $_->[9]". br; }
			if ($_->[10]) { $inities .= "<span style='font-weight: bold;'>proposer:</span> $_->[10]". br; }
			if ($_->[11]) { $inities .= "<span style='font-weight: bold;'>proposer:</span> $_->[11]". br; }
			if ($_->[12]) { $inities .= "<span style='font-weight: bold;'>registred:</span> $_->[12]". br; }
			if ($_->[13]) { $inities .= "<span style='font-weight: bold;'>validated:</span> $_->[13]". br; }
			$inities .= p;
			$inities .= 'Delete: <input type="checkbox" name='.$_->[0].' value="delete" onclick="alert(\'by checking this box you will exclude and delete the member\')">';
			$inities .= "</div>";
			$inities .= '<input type="submit" value="Submit">';
		}
		else {
			$profanes .= "<div style='border: 1px solid darkgrey; padding: 5px;'>";
			if ($_->[1]) { $profanes .= "<span style='font-weight: bold;'>First name:</span> $_->[1]". br; }
			if ($_->[2]) { $profanes .= "<span style='font-weight: bold;'>Middle name:</span> $_->[2]". br; }
			if ($_->[3]) { $profanes .= "<span style='font-weight: bold;'>Last name:</span> $_->[3]". br; }
			if ($_->[4]) { $profanes .= "<span style='font-weight: bold;'>Email:</span> $_->[4]". br; }
			if ($_->[5]) { $profanes .= "<span style='font-weight: bold;'>Institution:</span> $_->[5]". br; }
			if ($_->[6]) { $profanes .= "<span style='font-weight: bold;'>City:</span> $_->[6]". br; }
			if ($_->[7]) { $profanes .= "<span style='font-weight: bold;'>Country:</span> $_->[7]". br; }
			if ($_->[8]) { $profanes .= "<span style='font-weight: bold;'>publication:</span> $_->[8]". br; }
			if ($_->[9]) { $profanes .= "<span style='font-weight: bold;'>publication:</span> $_->[9]". br; }
			if ($_->[10]) { $profanes .= "<span style='font-weight: bold;'>proposer:</span> $_->[10]". br; }
			if ($_->[11]) { $profanes .= "<span style='font-weight: bold;'>proposer:</span> $_->[11]". br; }
			if ($_->[12]) { $profanes .= "<span style='font-weight: bold;'>registred:</span> $_->[12]". br; }
			if ($_->[13]) { $profanes .= "<span style='font-weight: bold;'>validated:</span> $_->[13]". br; }
			$profanes .= p;
			$profanes .= 'Validate: <input type="checkbox" name='.$_->[0].' value="validate">'. p;
			$profanes .= 'Delete: <input type="checkbox" name='.$_->[0].' value="delete" onclick="alert(\'by checking this box you will exclude and delete the member\')">';
			$profanes .= "</div>";
			$profanes .= '<input type="submit" value="Submit">';
		}
	}
	
	print 	html_header(\%headerHash),
			div ({-style=>'margin: 1% auto; width: 1000px; border: 0px solid black;'},
				$bandeau,
				"<form action='".url()."?action=validate' method='post'>",
				'<span style="color: crimson;">####### Applicants: ##############</span>', p,
				$profanes, p,
				'<span style="color: crimson;">####### Members: ##############</span>', p,
				$inities,
				"</form>"
			),
			html_footer();
}
elsif ($action eq 'validate') {
	#die join(',', param());
	my $display;
	my $req = "BEGIN; ";
	foreach (param()) {
		if (param($_) eq 'validate') { $req .= "UPDATE members SET validdate = ('now'::text)::date where index = ".$_."; "; }
		elsif (param($_) eq 'delete') { $req .= "DELETE FROM members WHERE index = ".$_."; "; }
		#$display .= $_.' = '.param($_).br;
	}
	$req .= "COMMIT;";
	if ( scalar param() ) { 
		my $sth = $dbc->prepare( $req ) or "Prepare error: $req ".$dbc->errstr;
		$sth->execute() or die"Execute error: $req ".$dbc->errstr;
	}
	
	print 	html_header(\%headerHash),
		div ({-style=>'margin: 1% auto; width: 1000px; border: 0px solid black;'},
			$bandeau,
			"Modifications done", p,
			a({-href=>url().'?action=display'}, "Back to members list")
		),
		html_footer();
}
elsif ($action eq 'register') {
	
	my $req =  "SELECT index, name FROM countries;";
	my $countries = request_tab($req, $dbc, 2);
	my $clist = '<select name="country"><option value=""></option>';
	foreach (@{$countries}) { $clist .= '<option value="'.$_->[0].'">'.$_->[1].'</option>'; }
	$clist .= '</select>';
	
	print 	html_header(\%headerHash),
			div ({-style=>'margin: 1% auto; width: 1000px; border: 0px solid black;'},
				$bandeau,
				div({-style=>"font-size: 18px; color: darkgreen; margin: 0 auto; width: 800px; text-align: center;"}, "IAS Membership registration"), p,
				div({-style=>"margin: 0 auto; width: 680px; font-size: 14px;"}, 
				
				"Membership is free for 'non-voting members' but restricted to people having showed interested into Auchenorrhyncha studies according to the statutes and as shown by at least two publications.", br,
				"Students or non publishing people must be recommended by two people already members of the society.", p,
				"Registrations are validated by the IAS executive committee before membership becomes effective.", br,
				"In addition 'Voting members' should pay a fee of 10 EUR/year directly to the treasurer", p,
				"<span style='color: red;'>By registrering to IAS you agree that your data will be registered in the IAS database.", br, 
				"All these data will remain confidential, exclusively for IAS administration and never pass to third party.</span>", br
				), p,
				"<script>$validate</script>",
				start_form(-name=>'Form', -method=>'post',-action=>url().'?action=insert', -onsubmit=>"return validateForm();"),
					'<table style="margin: 0 auto; width: 400px;">
					  <tr><td>First name<span style="color: red;">*</span></td><td><input type="text" name="firstname" size="40" class="finput"></td></tr>
					  <tr><td>Middle name</td><td><input type="text" name="middlename" size="40" class="finput"></td></tr>
					  <tr><td>Last name<span style="color: red;">*</span></td><td><input type="text" name="lastname" size="40" class="finput"></td></tr>
					  <tr><td>Email<span style="color: red;">*</span></td><td><input type="text" name="email" size="40" class="finput"></td></tr>
					  <tr><td>Institution</td><td><input type="text" name="institution" size="40" class="finput"></td></tr>
					  <tr><td>City</td><td><input type="text" name="city" size="40" class="finput"></td></tr>
					  <tr><td>Country</td><td>'.$clist.'</td></tr>
					</table><p>
					<table style="margin: 0 auto; width: 400px;">
						<tr><td colspan=2>Publication1<span style="color: red;">*</span></td></tr>
						<tr><td>&nbsp;&nbsp;&nbsp;&nbsp;Author(s)<span style="color: red;">*</span></td><td><input type="text" name="authors1" size="40" class="finput"></td></tr>
						<tr><td>&nbsp;&nbsp;&nbsp;&nbsp;Year<span style="color: red;">*</span></td><td><input type="number" name="year1" size="4" maxlength="4" class="finput"></td></tr>
						<tr><td>&nbsp;&nbsp;&nbsp;&nbsp;Title<span style="color: red;">*</span></td><td><input type="text" name="title1" size="40" class="finput"></td></tr>
						<tr><td>&nbsp;&nbsp;&nbsp;&nbsp;Vol. & pages<span style="color: red;">*</span></td><td><input type="text" name="references1" size="40" class="finput"></td></tr>
					 </table><p>
					 <table style="margin: 0 auto; width: 400px;">
						<tr><td colspan=2>Publication2<span style="color: red;">*</span></td></tr>
						<tr><td>&nbsp;&nbsp;&nbsp;&nbsp;Author(s)<span style="color: red;">*</span></td><td><input type="text" name="authors2" size="40" class="finput"></td></tr>
						<tr><td>&nbsp;&nbsp;&nbsp;&nbsp;Year<span style="color: red;">*</span></td><td><input type="number" name="year2" size="4" maxlength="4" class="finput"></td></tr>
						<tr><td>&nbsp;&nbsp;&nbsp;&nbsp;Title<span style="color: red;">*</span></td><td><input type="text" name="title2" size="40" class="finput"></td></tr>
						<tr><td>&nbsp;&nbsp;&nbsp;&nbsp;Vol. & pages<span style="color: red;">*</span></td><td><input type="text" name="references2" size="40" class="finput"></td></tr>
					 </table><p>
					 <table style="margin: 0 auto; width: 400px;">
					  <tr><td>Recommendation1:</td><td><input type="text" name="recommends1" size="40" class="finput"></td></tr>
					  <tr><td>Recommendation2:</td><td><input type="text" name="recommends2" size="40" class="finput"></td></tr>
					  <tr><td colspan="2" align="left" style="padding-top: 20px; padding-left: 100px;"><input type="submit" value="Submit"></td></tr>
					 </table>',
	 			end_form()
			),
			html_footer();
}
elsif ($action eq 'insert') {
	
	#die join(',', param());
	
	my $firstname = param('firstname');
	my $middlename = param('middlename') || undef;
	my $lastname = param('lastname');
	my $email = param('email');
	my $institution = param('institution') || undef;
	my $city = param('city') || undef;
	my $country = param('country') || undef;
	
	my $authors1 = param('authors1');
	my $year1 = param('year1');
	my $title1 = param('title1');
	my $references1 = param('references1');
	
	my $authors2 = param('authors2');
	my $year2 = param('year2');
	my $title2 = param('title2');
	my $references2 = param('references2');
	
	my $recommends1 = param('recommends1') || undef;
	my $recommends2 = param('recommends2') || undef;
	
	my @values = ($firstname, $middlename, $lastname, $email, $institution, $city, $country, $recommends1, $recommends2);
	
	my $mreq = "INSERT INTO members (index, firstname, middlename, lastname, email, institution, city, country, recommends1, recommends2, regdate) VALUES (default, ?, ?, ?, ?, ?, ?, ?, ?, ?, ('now'::text)::date );";
	
	my $pubsreq;
	if ($authors1 and $year1 and $title1 and $references1) {
		$pubsreq .= "INSERT INTO publications (index, authors, year, title, pubreferences) VALUES (default, ?, ?, ?, ? );";
		$pubsreq .= "UPDATE members SET ref_pub1 = (SELECT max(index) FROM publications) WHERE index = (SELECT max(index) FROM members);";
		push(@values, ($authors1, $year1, $title1, $references1));
	}
	if ($authors2 and $year2 and $title2 and $references2) {
		$pubsreq .= "INSERT INTO publications (index, authors, year, title, pubreferences) VALUES (default, ?, ?, ?, ? );";
		$pubsreq .= "UPDATE members SET ref_pub2 = (SELECT max(index) FROM publications) WHERE index = (SELECT max(index) FROM members);";
		push(@values, ($authors2, $year2, $title2, $references2));
	}

	
	
	my $req .= "BEGIN; $mreq $pubsreq COMMIT;";
	my $sth = $dbc->prepare( $req ) or "Prepare error: $req ".$dbc->errstr;
	$sth->execute( @values ) or die"Execute error: $req ".$dbc->errstr;
	
	print 	html_header(\%headerHash),
			div ({-style=>"margin: 1% auto; width: 1250px; border: 0px solid black;"},
				$bandeau,
				$aims,
				table({-border=>0}, Tr($menus, $encart), Tr($more))
			),
			html_footer();
}	

