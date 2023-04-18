package DBTNTAuthors;

use strict;
use warnings;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use CGI::Pretty;
use DBCommands qw (get_connection_params read_lang db_connection request_tab request_row);
use Style qw ($conf_file $background $css);

## CONSEILS POUR CREER LES CHAMPS AUTEURS
#  METTRE ONFOCUS SUR TOUS LES CHAMPS DU FORMULAIRE QUI CONTIENT LES CHAMPS AUTEURS = $onfocus
#  PUIS COPIER: le code de publications.pl de la fonction pub_form avec $form = nom du formulaire ( document.nomduform ) et $nbauts le nombre d'auteurs


BEGIN {
	use Exporter   ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
		
	@ISA         = qw(Exporter);
	@EXPORT      = qw($authorsJscript &makeAuthorsfields &AonFocus &add_author);
	%EXPORT_TAGS = ();
	
	@EXPORT_OK   = qw();
}
    
use vars      qw($authorsJscript &makeAuthorsfields &AonFocus &add_author);




my $dbc = db_connection(get_connection_params($conf_file));

my $authors = request_tab("SELECT nom, prenom FROM auteurs ORDER BY nom;",$dbc,2);
my @authors_first_names;
my @authors_last_names;

foreach (@{$authors}) {
	if ($_->[0]) { push (@authors_first_names,"$_->[0]"); }
	if ($_->[1]) { push (@authors_last_names,"$_->[1]"); } else { push (@authors_last_names,""); }
}
my $first_names_str = '"'.join('","',@authors_first_names).'"';
my $last_names_str = '"'.join('","',@authors_last_names).'"';

sub AonFocus {
	
	my ($prefix) = @_;
	
	return "clear_all_sugs('$prefix');availableCompletion('$prefix', 'none');reinit('$prefix');";
}

our $authorsJscript = "

	first_names = new Array($first_names_str);
	last_names = new Array($last_names_str);
	
	var sug = '';
	var sug_disp = '';
	
	test = 0;
	
	function getAuthor(pre, num) {
		
		var name_field = document.getElementById(pre+'AFN'+num);
		var phantom_field = document.getElementById(pre+'AFNsug'+num);
			
		var lname_field = document.getElementById(pre+'ALN'+num);
		var lphantom_field = document.getElementById(pre+'ALNsug'+num);
		
		if (phantom_field.value == 'Name') { phantom_field.value = ''; lphantom_field = ''; }
		
		var first_name = name_field.value;
		
		var lenf = first_name.length;
		//suggestion for author Initials
		sug_disp = '';
		//suggestion for author last name
		sug_displ = '';
		// memorized values
		sug = '';
		sugl = '';
		last = 0;
		
		matchings = new Array();
		
		if (first_name.length != 0) {
			// get matching author from array
			for (ele in first_names)  {
				if (first_names[ele].substr(0,lenf).toLowerCase() == first_name.toLowerCase() )  {
					if (!matchings.length) {
						if (lenf != first_names[ele].length) { sug_disp = first_name + first_names[ele].substr(lenf); }
						sug_displ = last_names[ele];
						sug = first_names[ele];
						sugl = last_names[ele];
					}
					matchings.push(ele);
				}
			}
		}
		
		if (!matchings.length) { availableCompletion(pre, 'none'); }
		else {		
			if(matchings.length == 1) {
				document.getElementById(pre+'NEXTbtn'+num).style.display = 'none';	
			}
			else { 
				document.getElementById(pre+'NEXTbtn'+num).style.display = 'block';		
			}
		}
	    
		phantom_field.value = sug_disp;
		if (!lphantom_field.value && !lname_field.value) { 
			lphantom_field.value = sug_displ; 
		}
	
		if (!sug.length) {
			lphantom_field.value = '';
			lname_field.value = '';
			document.getElementById(pre+'NEXTbtn'+num).style.display = 'none';
			document.getElementById(pre+'SUGbtn'+num).style.display = 'none';
		}
		else {
			document.getElementById(pre+'SUGbtn'+num).style.display = 'block';
		}
	}
	
	function setAuthor(pre, num) {
		var name_field = document.getElementById(pre+'AFN'+num);
		var phantom_field = document.getElementById(pre+'AFNsug'+num);
		var lname_field = document.getElementById(pre+'ALN'+num);
		var lphantom_field = document.getElementById(pre+'ALNsug'+num);
		name_field.value = sug;
			
		if (!lname_field.value) {lname_field.value = sugl; }
		hideCompletion(pre, num);
	}
		
	function hideCompletion (pre, num) {
		document.getElementById(pre+'NEXTbtn'+num).style.display = 'none';
		document.getElementById(pre+'SUGbtn'+num).style.display = 'none';
	}
	
	function testAvailability (pre, num) {
		var phantom_field = document.getElementById(pre+'AFNsug'+num);
		var lphantom_field = document.getElementById(pre+'ALNsug'+num);
		if ((!phantom_field.value || phantom_field.value == 'Name') && (!lphantom_field.value || lphantom_field.value == 'Initials')) { 
			document.getElementById(pre+'NEXTbtn'+num).style.display = 'none';
			document.getElementById(pre+'SUGbtn'+num).style.display = 'none';
		}
	}
	
	function availableCompletion (pre, num) {
		var index = 1;
		var goon = 1;
		while (goon) {
			
			var image = document.getElementById(pre+'SUGbtn'+index);
			var image2 = document.getElementById(pre+'NEXTbtn'+index);
			
			if (!image) { goon = 0 }
			else { 
				if (index != num || num == 'none') { 
					image.style.display = 'none'; 
					image2.style.display = 'none'; 
				}
			}
			index = index +1;
		}
	}
	
	function clear_sugs (pre, num) {

			var name_field = document.getElementById(pre+'AFN'+num);
			var phantom_field = document.getElementById(pre+'AFNsug'+num);
				
			var lname_field = document.getElementById(pre+'ALN'+num);
			var lphantom_field = document.getElementById(pre+'ALNsug'+num);
			
			phantom_field.value = ''; 
			lphantom_field.value = '';
	}
	
	function clear_all_sugs (pre) {
		
		var num = 1;
		var goon = 1;
		while (goon) {
						
			var name_field = document.getElementById(pre+'AFN'+num);
			var phantom_field = document.getElementById(pre+'AFNsug'+num);
				
			var lname_field = document.getElementById(pre+'ALN'+num);
			var lphantom_field = document.getElementById(pre+'ALNsug'+num);
			
			if (!phantom_field) { goon = 0 }
			else { 
				phantom_field.value = ''; 
				lphantom_field.value = '';
			}

			num = num +1;
		}
	}
	
	function clear_values (pre, num) {

		var name_field = document.getElementById(pre+'AFN'+num);
		var phantom_field = document.getElementById(pre+'AFNsug'+num);
			
		var lname_field = document.getElementById(pre+'ALN'+num);
		var lphantom_field = document.getElementById(pre+'ALNsug'+num);
		
		if(name_field.length > 1) { name_field.value = name_field[0]; }
		lname_field.value = '';
	}
	
	function reinit (pre) {
		
		var num = 1;
		
		while (document.getElementById(pre+'AFN'+num)) {
			var name_field = document.getElementById(pre+'AFN'+num);
			var phantom_field = document.getElementById(pre+'AFNsug'+num);
				
			var lname_field = document.getElementById(pre+'ALN'+num);
			var lphantom_field = document.getElementById(pre+'ALNsug'+num);
						
			if (name_field.value != '') { 
				phantom_field.value = ''; 
				lphantom_field.value = '';
			} else { 
				phantom_field.value = 'Name';
				if (lname_field.value != '') {
					lphantom_field.value = 'Initials';
				}
				else {
					lphantom_field.value = 'Initials';
				}
			}
						
			num = num +1;
		}
	}
	
	function get_next_author (pre, num) {
		
		test = 1;
		
		var name_field = document.getElementById(pre+'AFN'+num);
		var phantom_field = document.getElementById(pre+'AFNsug'+num);
			
		var lname_field = document.getElementById(pre+'ALN'+num);
		var lphantom_field = document.getElementById(pre+'ALNsug'+num);
				
		if (phantom_field.value == 'Name') { phantom_field.value = ''; lphantom_field = ''; }
		
		var first_name = name_field.value;
		
		var lenf = first_name.length;
		
		last = last +1;
		
		if (last >= matchings.length) { 
			last = 0;
		}
		
		var ii = matchings[last];
		
		if (lenf != first_names[ii].length) { sug_disp = first_name + first_names[ii].substr(lenf); }
		sug_displ = last_names[ii];
		sug = first_names[ii];
		sugl = last_names[ii];
		
		phantom_field.value = sug_disp;
		lphantom_field.value = sug_displ; 
	
		if (!sug.length) {
			document.getElementById(pre+'NEXTtn'+num).style.display = 'none';
			document.getElementById(pre+'SUGbtn'+num).style.display = 'none';
		}
		else {
			document.getElementById(pre+'NEXTtn'+num).style.display = 'block';
			document.getElementById(pre+'SUGbtn'+num).style.display = 'block';
		}
	}
	
	function ToUpperFirst (pre, num) {
		
		var name = document.getElementById(pre+'AFN'+num);
		var lname = document.getElementById(pre+'ALN'+num);
				
		name.value = name.value.substr(0,1).toUpperCase() + name.value.substr(1,name.value.length);
		lname.value = lname.value.substr(0,lname.value.length).toUpperCase();
	}
	
	function clear_fields (pre, num) {
		
		var name = document.getElementById(pre+'AFN'+num);
		var lname = document.getElementById(pre+'ALN'+num);
				
		name.value = '';
		lname.value = '';
	}

	function ChangeNbAuts (form,field,todo,number,targeted,taged) { 
	
		if (todo == 'more') { field.value = number+1; }
		else { if (todo == 'less' && number > 1) { field.value = number-1; } }

		form.action = targeted+'?action=fill&page='+taged;
		form.submit();
	}";

sub makeAuthorsfields {

	my ($prefix, $i) = @_;
		
	my $fields = 	"<div style='position: relative; margin: 2px 0 2px 0; height: 22px;' >
			
				<div style='position: absolute; top: 0; left: 0; width: 150px; z-index: 1;'>
					<input 	type='text' 
						name='".$prefix."AFNsug$i' 
						id='".$prefix."AFNsug$i' 
						style='background: #FFFFEE; color :#cc2222; border: 1px solid #999; width: 150px; padding: 2px' 
						disabled 
					/>
				</div>
				
				<div style='position: absolute; top: 0; left: 0; width: 150px; z-index: 2;'>
					<input 	type='text' 
						autocomplete='off' 
						name='".$prefix."AFN$i' 
						id='".$prefix."AFN$i' 
						style='background: none; color: navy; border: 1px solid #999; width: 150px; padding: 2px;' 
						value=".'"'.param($prefix."AFN$i").'"'.
												
						"onfocus=\"this.form.".$prefix."ALN$i.disabled = false;
							  clear_all_sugs('$prefix');
							  clear_fields('$prefix', $i);
							  availableCompletion('$prefix', $i);
							  getAuthor('$prefix', $i);\"
						onkeyup=\"this.form.".$prefix."ALN$i.disabled = false;
							  clear_sugs('$prefix', $i);
							  availableCompletion('$prefix', $i);
							  getAuthor('$prefix', $i)\"
						onBlur=\"clear_all_sugs('$prefix');ToUpperFirst('$prefix', $i);reinit('$prefix');\"
					/>
				</div>
				
				<div style='position: absolute; top: 0; left: 155px; width: 150px; z-index: 1;'>
					<input 	type='text' 
						name='".$prefix."ALNsug$i' 
						id='".$prefix."ALNsug$i' 
						style='background: #FFFFEE; color :#cc2222; border: 1px solid #999; width: 150px; padding: 2px' 
						disabled 
					/>
				</div>
				
				<div style='position: absolute; top: 0; left: 155px; width: 150px; z-index: 2;'>
					<input autocomplete='off' type='text' 
					name='".$prefix."ALN$i' 
					id='".$prefix."ALN$i'  
					style='background: none; color: navy; border: 1px solid #999; width: 150px; padding: 2px' 
					value=".'"'.param($prefix."ALN$i").'"'.
					"onfocus=\"if(this.form.".$prefix."ALNsug$i.value == 'Initials') { this.form.".$prefix."ALN$i.disabled = true; }
						  clear_sugs('$prefix', $i);
						  availableCompletion('$prefix', 'none');
						  \" 
					onBlur=\"ToUpperFirst('$prefix', $i);\"
					/>
				</div>
				
				<div 	id='".$prefix."NEXTbtn$i' style='position: absolute; top: 2px; left:320px; z-index: 3; display: none;' 
					onClick=\"	clear_values('$prefix', $i);
							get_next_author('$prefix', $i)\" 
					onMouseOver=\"testAvailability('$prefix', $i)\"
				>
					<img src='/Editor/next_0.png' border='0'>
				</div>				
				
				<div 	id='".$prefix."SUGbtn$i' style='position: absolute; top: 2px; left:375px; z-index: 3; display: none;' 
					onClick=\"setAuthor('$prefix', $i);clear_sugs('$prefix', $i);\" 
					onMouseOver=\"testAvailability('$prefix', $i)\"
				>
					
					<img src='/Editor/ok0.png' border='0'>
				</div>
				
			</div>";
}


sub add_author {

	my ($name,$prenom) = @_;

	$name =~ s/'/\\'/g;
	$prenom =~ s/'/\\'/g;
	
	$name = ucfirst($name);
	$prenom = ucfirst($prenom);

	my $flist = "index, nom"; #list of fields
	my $vlist = "default,'$name'"; #list of values

	my $conditions = '';
	if ($prenom) { $flist .= ", prenom"; $vlist .= ",'$prenom'"; $conditions .= "AND prenom = '$prenom'";} else { $conditions .= "AND prenom is NULL"; }

	my $index;
	my $result = request_tab("select index from auteurs where nom = '$name' $conditions;",$dbc,1);
		
	if (scalar(@{$result})) {

		($index) = @{$result};

	} else {
				
		my $sth = $dbc->prepare( "INSERT INTO auteurs ($flist) VALUES ($vlist);" ) or print header(),start_html(),$dbc->errstr,end_html();

		$sth->execute() or print header(),start_html(),$dbc->errstr,end_html();

		my $req = "SELECT MAX(index) FROM auteurs;";
		($index) = @{request_tab($req,$dbc,1)};
		
	}

	return $index;

}
