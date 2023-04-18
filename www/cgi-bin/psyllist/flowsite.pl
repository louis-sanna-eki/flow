#!/usr/bin/perl

use strict;
use CGI qw/:standard/;
use CGI::Carp qw( fatalsToBrowser ); # display errors in browser
#SOFIZ comment
#use CGI::ProgressBar qw/:standard/;
use DBCommands qw (get_connection_params db_connection request_hash request_tab request_row get_title);
use URI::Escape;
#jompo
use open ':std', ':encoding(UTF-8)';

my $url = url();
$| = 1;

# variables de navigation
my $xbase;
my $xpage; 
my $xlang;
my $script;
my $test = '<div id="testDiv"></div>';
if (url_param('db')) { $xbase = url_param('db'); } else { $xbase = 'psylles'; }
if (url_param('page')) { $xpage = url_param('page'); } else { $xpage = 'home'; }
if (url_param('lang')) { $xlang = url_param('lang'); } else { $xlang = 'en'; }
my $searchtable = param('searchtable') || 'noms_complets';
my $searchid = param('searchid');
Delete('searchid');
my $docpath = '/flowdocs/';

my $analytics =<<END;

      window.dataLayer = window.dataLayer || [];
      function gtag(){dataLayer.push(arguments);}
      gtag('js', new Date());

      gtag('config', 'UA-21288992-1');


	/*var _gaq = _gaq || [];
	_gaq.push(['_setAccount', 'UA-21288992-1']);
	_gaq.push(['_trackPageview']);
	(function() {
		var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
		ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
		var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
	})();
	
	(function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
	(i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
	m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
	})(window,document,'script','//www.google-analytics.com/analytics.js','ga');
	
	ga('create', 'UA-21288992-1', 'hemiptera.infosyslab.org');
	ga('require', 'displayfeatures');
	ga('send', 'pageview');*/

END
my $iconMouseOver = "	
	function findPosII(obj) {
		var curleft = curtop = 0;
		var strleft = strtop = '';
		if (obj.offsetParent) {
			do {
				if (obj.tagName != 'TABLE') { curleft += obj.offsetLeft; }
				curtop += obj.offsetTop;
				
				strleft += obj.tagName + ':' + obj.offsetLeft + '<br>';
				strtop += obj.tagName + ':' + obj.offsetTop + '<br>';
			
			} while (obj = obj.offsetParent);
		}
		return [curleft,curtop,strleft,strtop];
	}
	function makeBulle (myelem, myid) {
		var bulle = document.getElementById(myid);
		var pos = findPosII(myelem);
		bulle.style.left = pos[0] + 30 + 'px';
		bulle.style.top = pos[1] - 9 + 'px';
		bulle.style.display = 'block';
		/*if (window.location.toString().search('test=1') > 0) {
			document.getElementById('testDiv').innerHTML = pos[2] + pos[3];
		}*/
	}";

my $pagetitle = "Psylles Website";

# traductions
my $config_file = '/etc/flow/psyllesexplorer.conf';

my $config = get_connection_params($config_file);

my $traduction = read_lang($config, $xlang);

my $dbc = db_connection($config);

my $last = request_row("SELECT modif FROM synopsis;",$dbc);

my $docfullpath = '/var/www/html/Documents/flowdocs/';
#my $docfullpath = '/var/www/html/Documents/flowdocs/';

my $searchjs = $docfullpath.$config->{'SEARCHJS'};

my %types = (
	'noms_complets' => $traduction->{sciname}->{$xlang},
	'auteurs' => $traduction->{author}->{$xlang},
	'pays' => $traduction->{country}->{$xlang}
);

my $search_actions = "
	function clear_search_except(from, identity) {
		var identities = new Array('".join("','", sort {$types{$a} cmp $types{$b}} keys(%types))."');
		var valeur;
		for (index in identities) {
			if (document.getElementById(identities[index]).value) { valeur = document.getElementById(identities[index]).value; }
			if (identities[index] != identity) {
				document.getElementById(identities[index]).style.visibility = 'hidden';
			}
			else {
				document.getElementById(identities[index]).style.visibility = 'visible';
			}
			document.getElementById(identities[index]).value = '".ucfirst($traduction->{search}->{$xlang})."';
		}
		if (from == 'popup') {
			if (valeur) {
				document.getElementById(identity).value = valeur;
				document.getElementById(identity).focus();
			}
		}
	}
";

my $typdef = $searchtable;

my %attributes = (
	'noms_complets' => {'class'=>'searchOption'},
	'auteurs' => {'class'=>'searchOption'},
	'pays' => {'class'=>'searchOption'}
);

my $search = url_param('search') || '';
for (my $i = 1; $i < scalar(keys(%types)) + 1; $i++) {
	my $schstr = param("search$i");
	if (ucfirst($schstr) ne ucfirst($traduction->{search}->{$xlang})) { $search = $schstr; }
}

my $args;
my $thesauri;
my $onload;
if ( open(SEARCHJS, "<$searchjs") ) {
	
	my $delai = time - (stat SEARCHJS)[9];
	
	close(SEARCHJS);
		
	if ($delai < 1800 and !url_param('reload')) {

		$onload .= "AutoComplete_Create('noms_complets', noms_complets, 'noms_completsids', authors, 10);";
		$onload .= "AutoComplete_Create('auteurs', auteurs, auteursids, '', 10);";
		$onload .= "AutoComplete_Create('pays', pays, paysids, '', 10);";
	}
	else {
		open(SEARCHJS, ">$searchjs");
		
		my $names = request_tab("SELECT nc.index, nc.orthographe, CASE WHEN (SELECT ordre FROM rangs WHERE index = nc.ref_rang) > (SELECT ordre FROM rangs WHERE en = 'genus') THEN nc.autorite ELSE coalesce(nc.autorite, '') || coalesce(' (' || (SELECT orthographe FROM noms WHERE index = (SELECT ref_nom_parent FROM noms WHERE index = nc.index)) || ')', '') END FROM noms_complets AS nc LEFT JOIN rangs AS r ON nc.ref_rang = r.index WHERE r.en not in ('order', 'suborder') ORDER BY nc.orthographe;",$dbc,2);
		my $authors = request_tab("SELECT index, coalesce(nom || ' ', '') || coalesce(prenom, '') AS auteur from auteurs;",$dbc,2);
		my $distribs = request_tab("SELECT index, $xlang from pays where index in (SELECT DISTINCT ref_pays FROM taxons_x_pays);",$dbc,2);
		
		search_formating('noms_complets', $names, \$thesauri, \$onload, $dbc);
		search_formating('auteurs', $authors, \$thesauri, \$onload, $dbc);
		search_formating('pays', $distribs, \$thesauri, \$onload, $dbc);

		print SEARCHJS $thesauri;
	
		close(SEARCHJS);
	}
}
else {
	die "Can't open $searchjs";
}

my $header = header({-Type=>'text/html', -Charset=>'UTF-8'}).
	start_html(	-title  =>"Planthoppers: $pagetitle",
			-author =>	'anta@mnhn.fr',
			-head   =>[
			meta({-http_equiv => 'Content-Type', -content => 'text/html; charset=UTF-8'}),
			meta({-name => "copyright", -content => "FLOW"}),
			meta({-name => "publisher", -content => "FLOW"}),			
			meta({-name => "google-site-verification", -content => "hRYnUapr5kRBc7qIuZ4_WmKgulqneO3AZQsjjWUowUA"}),
			Link({	-rel=>'shortcut icon',
				-href=>$docpath.'wheel/img/minifulgo.png',
				-type=>'image/x-icon'}),

            Link({	-rel=>'stylesheet',
            				-href=>'https://cdn.jsdelivr.net/gh/openlayers/openlayers.github.io@master/en/v6.5.0/css/ol.css'
            				}),


           Link({	-rel=>'icon',
				-href=>$docpath.'wheel/img/minifulgo.png',
				-type=>'image/x-icon'})
			],
			-meta   => {'keywords'=>'FLOW, Fulgoromorpha, planthoppers, Fulgoroidea, Taxonomy, dbtnt',
					'description'=>'FLOW: a taxonomic and bibliographical database for planthoppers (Insecta Hemiptera Fulgoromorpha Fulgoroidea) their distribution and biological interactions'
				},
			-style  => 	[
						#{'src'=>'/explorerdocs/css/pace.css'},
						{'src'=>$docpath.'flow.css'}
						],
			-base => 'true',
			-target => '_parent',
			-script => 	[
						{-language=>'JAVASCRIPT', -src=>$docpath.'browserdetect.js'},
						{-language=>'JAVASCRIPT', -src=>'https://cdn.jsdelivr.net/gh/openlayers/openlayers.github.io@master/en/v6.5.0/build/ol.js'},
						{-language=>'JAVASCRIPT',-src=>$docpath.'SearchAutoComplete_utf8.js'},
						{-language=>'JAVASCRIPT',-src=>$docpath.'javascriptFuncs.js'},
						{-language=>'JAVASCRIPT',-src=>$docpath.$config->{'SEARCHJS'}},
						{-language=>'JAVASCRIPT',-src=>$docpath.'js/jquery-1.11.0.min.js'},
						#jompo; la ligne suivante etait avant et generait une erreur pour mouseScrolling qui etait appele avant jquery ;-)
						{-language=>'JAVASCRIPT',-src=>$docpath.'js/mouseScrolling.js'},
						{-language=>'JAVASCRIPT',-src=>$docpath.'js/jquery.infinitecarousel2_0_2.js'},
						{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/json2.js'},
						{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/OpenLayers-2.13.1/OpenLayers.js'},
						{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/compositeMaps.js'},
						{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/cs_script.js'},
						#{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/pace.js'},
						{-language=>'JAVASCRIPT',-src=>'https://www.googletagmanager.com/gtag/js?id=UA-21288992-1'},

						$analytics,
						$search_actions,
						$iconMouseOver
					],
			-onLoad	=> "	clear_search_except('onload', '$typdef');
					$onload
					if (isIE) {
						document.getElementById('searchpop').style.height = '20px';
					}"
	);

$args .= " -searchtable='$searchtable' ";
if ($search) { $args .= " -search=\"$search\" " } else { $args .= " -search='' " }
if ($searchid) { $args .= " -searchid=$searchid " }

my $search_fields;
my $z = 1;
foreach my $key (sort {$types{$a} cmp $types{$b}} keys(%types)) {
	$search_fields .= textfield(	-name=>"search$z",
					-class=>'searchField',
					-style=>"z-index: $z;",
					-id=>"$key",
					-onFocus=>"if(this.value != '".ucfirst($traduction->{search}->{$xlang})."'){
					    console.log(this.getAttribute('id'));
					    AutoComplete_ShowDropdown(this.getAttribute('id'));

					} else { this.value = '' }",
					-onBlur=>"if(!this.value) { this.value = '".ucfirst($traduction->{search}->{$xlang})."' }"
			);
	$z++;
}

my $carousel;

#if (url_param('test')) {

my %photos = (

'Tropiduchidae' => 1,
'Tropiduchidae 2' => 1,
'Trienopa typica' => 1,
'Tettigometra laeta' => 1,
'Tachycixius venustulus' => 1,
'Reptalus panzeri' => 1,
'Ranissus egerneus' => 1,
'Pterodictya reticularis' => 1,
'Plectoderes scapularis' => 1,
'Plectoderes flavovittata' => 1,
'Phrictus cf tripartitus' => 1,
'Phrictus cf tripartitus 2' => 1,
'Parorgerius platypus' => 1,
'Ormenis sp' => 1,
'Omolicna sp' => 1,
'Oeclidius browni' => 1,
'Odontoptera carrenoi' => 1,
'Noabennarella costaricensis' => 1,
'Meenoplus albosignatus' => 1,
'Lappida sp' => 1,
'Issidae' => 1,
'Hemisphaerius sp' => 1,
'Fulgoroidea' => 1,
'Fulgoroidea 2' => 1,
'Fulgora cf laternaria 2' => 1,
'Fulgora cf laternaria 1' => 1,
'Flatidae' => 1,
'Fipsianus andreae' => 1,
'Eurybregma nigrolineata' => 1,
'Epibidis sp' => 1,
'Enchophora prasina' => 1,
'Dictyophara europaea rosea' => 1,
'Dictyophara europaea 2' => 1,
'Dictyophara europaea 1' => 1,
'Derbidae' => 1,
'Dendrokara monstrosa 2' => 1,
'Dendrokara monstrosa 1' => 1,
'Conomelus lorifer' => 1,
'Cixiidae' => 1,
'Chlorionidea flava' => 1,
'Carthaeomorpha rufipes' => 1,
'Caliscelis bonellii' => 1,
'Asiraca clavicornis' => 1,
'Anotia sp' => 1

);

my $phts;
foreach (keys(%photos)) { $phts .= '<li><img alt="FLOW planthopper fulgoroidea fulgoromorpha insect" src="/flowfotos/carousel/thumbnails/'.$_.'.png" height="150" width="200" onMouseOver="this.style.cursor=\'pointer\';" onclick="ImageMax(\'/flowfotos/carousel/1280/'.$_.'.jpg\');"/></li>'; }

$carousel ="<script type='text/javascript'>".
'$(function(){
	$("#carousel").infiniteCarousel({
		transitionSpeed: 4000,
		displayTime: 0,
		displayProgressBar: false,
		displayThumbnails: false,
		displayThumbnailNumbers: false,
		displayThumbnailBackground: false,
		imagePath: "",
		easeLeft: "linear",
		easeRight: "linear",
		inView: 5,
		padding: "0px",
		advance: 1,
		showControls: false,
		autoHideControls: false,
		autoHideCaptions: false,
		autoStart: true,
		prevNextInternal: true
	});
	$("div.thumb").parent().css({"margin":"0 auto","width":"900px"});
});'.
"function ImageMax(chemin) {
	var html = '<html><body><img src=".'"'."'+chemin+'".'"'." border=0 height=\"900\"/></body></html>';
	var popupImage = window.open('','_blank','toolbar=0, location=0, scrollbars=0, directories=0, status=0, resizable=1');
	popupImage.document.open();
	popupImage.document.write(html);
	popupImage.document.close();
};".
"</script>

<div id='carousel' style='width: 900px;'>
	<ul>
		$phts
	</ul>
</div>";

#}

# varibales globales pour tout site		
my ($html, $bandeau, @menus,%submenus,%menulinks, @menuSpaces, $activepage, $content);

## LE CONTENU ##################################
my $card = url_param('card') || '';
#if ($xbase eq 'flow') {
	if ($xpage eq 'explorer') {
		
		my $param;
		if ($param = url_param('db')) { $args .= " -db=$param " }
		if ($param = url_param('card')) { $args .= " -card=$param " }
		
		if ($param eq 'board') { $activepage = "Synopsis" }
		else { $activepage = $traduction->{'flow_db'}->{$xlang} }
		
		if ($param = url_param('id')) { $args .= " -id=$param " }
		if ($param = url_param('lang')) { $args .= " -lang=$param " }
		if ($param = url_param('alph')) { $args .= " -alph=$param " }
		if ($param = url_param('from')) { $args .= " -from=$param " }
		if ($param = url_param('to')) { $args .= " -to=$param " }
		if ($param = url_param('rank')) { $args .= " -rank=$param " }
		if ($param = url_param('mode')) { $args .= " -mode=$param " }
		if ($param = url_param('privacy')) { $args .= " -privacy=$param " }
		if ($param = url_param('limit')) { $args .= " -limit=$param " }

		my $id = url_param('id') || '';
		
		#if (url_param('card') eq 'searching') { die param('hiddensearch'). " = $args" }
		
		my $alph = url_param('alph') || 'NULL';
		
		$pagetitle = get_title($dbc, $xbase, $card, $id, $search, $xlang, 'NULL', $alph, $traduction);


				
#		$script = "/var/www/html/perl/explorer20.pl $args";
		$script = "/var/www/html/perl/explorer20.pl $args";
	}
	elsif ($xpage eq 'project') {
					
		$content = 	table(
					Tr(
					td({-style=>"padding-right: 20px; width: 700px;"},
							span({-name=>'ori', -class=>'paragrafTitleStyle'}, $traduction->{'ori_key'}->{$xlang}),p,
							$traduction->{'oritxt'}->{$xlang}
						),
						td({-style=>'width: 100px;'}, img({-src=>$docpath."intricata.png", alt=>"intricata", width=>'100px', height=>'200px'}))
					)
				).
				table(
					Tr(
						
						td({-style=>"padding-right: 20px;"}, img({-src=>$docpath."vohimana3.png", alt=>"vohimana", width=>'200px', height=>'150px'}),p),
						td(
							span({-name=>'desc', -class=>'paragrafTitleStyle'}, $traduction->{'descr_key'}->{$xlang}),p,
							$traduction->{'presenttxt'}->{$xlang}
						)
					)
				).
				table(
					Tr(
						
						td({-style=>"padding-right: 20px;"},
							span({-name=>'tech', -class=>'paragrafTitleStyle'}, $traduction->{'tech_key'}->{$xlang}),p,
							$traduction->{'techtxt'}->{$xlang}
						),
						td(img({-src=>$docpath."fulgore2.png", alt=>"fulgore", width=>'180px', height=>'200px'}))
					)
				).
				table(
					Tr(
						
						td(
							span({-name=>'com', -class=>'paragrafTitleStyle'}, $traduction->{'community'}->{$xlang}),p,
							$traduction->{'commutxt'}->{$xlang}
						)
					)
				).
				table(
					Tr(
						
						td({-style=>"padding-right: 20px;"},
							span({-name=>'col', -class=>'paragrafTitleStyle'}, $traduction->{'collabos'}->{$xlang}), br, br,
							$traduction->{'collabtxt'}->{$xlang}, br, br,
							a({-href=>"http://www.gbif.org/"}, img{-src=>$docpath.'gbif.jpg', -style=>'border: 0; height:50px; width: 89px;'}),
							a({-href=>"http://www.sp2000.org/"}, img{-src=>$docpath.'sp2k.png', -style=>'border: 0; height:50px; width: 113px;'}),
							a({-href=>"http://www.biocase.org/index.shtml"}, img{-src=>$docpath.'biocase.png', -style=>'border: 0; height:50px; width: 77px;'}), p
						)
					)
				).
				table(
					Tr(
						td({-style=>"padding-right: 20px;"},
							span({-name=>'ctb', -class=>'paragrafTitleStyle'}, $traduction->{'contrib_key'}->{$xlang}), p({-style=>'text-indent: 20px'}),
							$traduction->{'contribtxt'}->{$xlang}
						)
					)
				).
				table(
					Tr(
						td(
							$traduction->{'dbtnt_standards'}->{$xlang}. p
						)
					)
				).
				span({-class=>'paragrafTitleStyle'}, $traduction->{'arigato'}->{$xlang}). p.	
				$traduction->{'thkintro'}->{$xlang}.		
				ul( "$traduction->{'fulgothanks'}->{$xlang}" );

			$content = br.div({-class=>'contentContainer card', -style=>'width: 970px; padding: 15px;'}, $content);
	}
	elsif ($xpage eq 'intro') {
		
		$content  = br.div({-class=>'contentContainer card', -style=>'width: 970px; margin-left: 0px; padding: 15px;'},
			
			span({-class=>'paragrafTitleStyle'}, $traduction->{'fulgointrotitle'}->{$xlang}), p({-style=>'text-indent: 20px'}),
			
			$traduction->{'fulgointro'}->{$xlang}, p({-style=>'text-indent: 20px'}),
			
			img({-src=>$docpath.'DSC02119.jpg', -style=>"width: 259px; height: 194px"}),

			img({-src=>$docpath.'DSC02158.jpg', -style=>"width: 259px; height: 194px"}),

			img({-src=>$docpath.'IMG_0492.jpg', -style=>"width: 257px; height: 194pix"}), br, br,

			span({-class=>'paragrafTitleStyle'}, $traduction->{'beetitle'}->{$xlang}), p({-style=>'text-indent: 20px'}),
			
			$traduction->{'fulgobio'}->{$xlang}, br, br,

			span({-class=>'paragrafTitleStyle'}, $traduction->{'econotitle'}->{$xlang}), p({-style=>'text-indent: 20px'}),
			
			$traduction->{'pests'}->{$xlang}, br, br,
			
			span({-class=>'paragrafTitleStyle'}, $traduction->{'fulgobiogeotitle'}->{$xlang}), p({-style=>'text-indent: 20px'}),
			
			$traduction->{'fulgobiogeo'}->{$xlang}, br, br,

			img({-src=>$docpath.'DSC02404.jpg', -style=>"width: 150px; height: 200px; margin-right: 50px; "}),

			img({-src=>$docpath.'IMG_0234.jpg', -style=>"width: 133px; height: 200px; margin-right: 50px;"}),

			img({-src=>$docpath.'IMG_0380.jpg', -style=>"width: 133px; height: 200px"}), br, br,
			
			span({-class=>'paragrafTitleStyle'}, $traduction->{'fulgomorphotitle'}->{$xlang}), p({-style=>'text-indent: 20px'}),
			
			$traduction->{'fulgomorpho'}->{$xlang}, br, br,

			img({-src=>$docpath.'IMG_0301.jpg', -style=>"width: 143px; height: 200px; margin-right: 50px; "}),

			img({-src=>$docpath.'IMG_0469.jpg', -style=>"width: 300px; height: 200px"}), br, br,
			
			span({-class=>'paragrafTitleStyle'}, $traduction->{'fulgophylotitle'}->{$xlang}), p({-style=>'text-indent: 20px'}),
			
			$traduction->{'fulgophylo'}->{$xlang}, br, br,
			
			span({-class=>'paragrafTitleStyle'}, $traduction->{'refstitle'}->{$xlang}), p({-style=>'text-indent: 20px'}),

			div({-style=>'position: relative; overflow: auto; height: 450px; width: 950px; margin-top: 20px; padding: 0; background: transparent;'},
				$traduction->{'flow_refs_list'}->{$xlang}
			)
		);
	}
	elsif ($xpage eq 'map') {
		$content .= 	div({-class=>'contentContainer'},
					"<div 	style='position: relative; overflow: auto; height: 450px; width: 940px; margin-top: 20px; padding: 0; background: transparent;'
						id='map'>
					</div>
					<script src='http://maps.google.com/maps?file=api&amp;v=2&amp;key=ABQIAAAAjpkAC9ePGem0lIq5XcMiuhR_wWLPFku8Ix9i2SXYRVK3e45q1BQUd_beF8dtzKET_EteAjPdGDwqpQ'></script>
					<script type='text/javascript'>
					// make map available for easy debugging
					var map;
					
					// increase reload attempts
					OpenLayers.IMAGE_RELOAD_ATTEMPTS = 3;
					
					function init(){
						var options = {
							projection: new OpenLayers.Projection('EPSG:900913'),
							displayProjection: new OpenLayers.Projection('EPSG:4326'),
							units: 'm',
							numZoomLevels: 18,
							maxResolution: 156543.0339,
							maxExtent: new OpenLayers.Bounds(-20037508, -20037508, 20037508, 20037508.34)
						};
						map = new OpenLayers.Map('map', options);
						
						var gsat = new OpenLayers.Layer.Google(
						'Google Satellite',
						{type: G_SATELLITE_MAP, 'sphericalMercator': true, numZoomLevels: 22}
						);
							
						map.addLayers([gsap]);
						map.zoomToMaxExtent();
					}
					init();
					</script>"
				);

	}
	else {		
		my $mnhn = a({-href=>"http://www.mnhn.fr/museum/foffice/transverse/transverse/accueil.xsp", -style=>'text-decoration: none;', -target=>'_blank'},
					img({-src=>$docpath.'logo_mnhn.png', -alt=>"MNHN", -style=>'border: 0;', -height=>'80px'}));
		my $upmc = a({-href=>"https://www.sorbonne-universite.fr", -style=>'text-decoration: none;', -target=>'_blank'},
					img({-src=>$docpath.'sorbone_university.png', -alt=>"UPMC", -style=>'border: 0;', -height=>'60px'}));
#		my $dbtnt = a({-href=>"http://hemiptera.infosyslab.fr/dbtnt/", -style=>'text-decoration: none;', -target=>'_blank'},
		my $dbtnt = a({-href=>"http://infosyslab.mnhn.fr/dbtnt/", -style=>'text-decoration: none;', -target=>'_blank'},
					img({-src=>'/dbtnt/images/logo.png', -alt=>"DBTNT", -style=>'border: 0;', -height=>'40px'}));
		$dbtnt = '';
		$content = 	#img({-class=>'rotate30', -src=>"/explorerdocs/CoLprize.png", -style=>'float: right; width: 175px; margin-top: -2px; margin-left: 8px;', title=>'CoL FLOW'}).						
					div({-style=>'text-align: center;'},
						#img({-src=>'flowWave.png', -alt=>"FLOW", -style=>"margin-top: 0 auto; padding: 20px 0 20px 0;"}),
						br,
						#div({-class=>'rotate30 tampon', -style=>'color: red; border-color: red;'}, "<br>Suprageneric taxa synopsis <br>now available<br>". img({-src=>"/explorerdocs/stats.png", -style=>'width: 28px; margin-top: 5px;', title=>'Taxon synopsis'}) ),
						table({-border=>0}, 
							Tr(	td({-style=>'width: 300px; text-align: center;'},$mnhn), 
								td({-style=>'width: 400px; text-align: center; font-size: 66px;', -rowspan=>2}, 'PSYLLES'), 
								td({-style=>'width: 300px; text-align: center; vertical-align: bottom;'}, $dbtnt.br.br)
							),
							Tr(	td({-style=>'width: 300px; text-align: center; vertical-align: top;'}, $upmc),
								td({-style=>'width: 300px; text-align: center; vertical-align: top;'}, "Version: ", span({-style=>"font-size: 110%; font-weight: bold"}, 8), br,
								"$traduction->{'dmaj'}->{$xlang}: ", span({-style=>"font-size: 110%; font-weight: bold"}, $last))
							)
						),
						$traduction->{'home_intro'}->{$xlang}, p({-style=>'text-indent: 20px'})
					);
		
		$content  = br.div({-class=>'contentContainer card'}, $content . $carousel . br );
	}
	
if (url_param('loading')) {
		
	my $frame = url(-path_info=>1,-query=>1);
	$frame =~ s/;loading=1//;
	
	my $framecss = "overflow:hidden;overflow-x:hidden;overflow-y:hidden;height:100%;width:100%;position:absolute;top:0px;left:0px;right:0px;bottom:0px;border:none;z-index:10;";
	$content .= div({-class=>'contentContainer'},
		div({-id=>'loadDiv', -style=>'position: relative; top: 146px; left: 46%; z-index=11;'}, "loading...<br><br>".img({-src=>"/flowdocs/flowloading1.gif", -style=>"width: 40px;"})).
		'<iframe id="mainFrame" src="'.$frame.'" style="'.$framecss.'" height="100%" width="100%" onload="'."document.getElementById('loadDiv').style.display = 'none'".';"></iframe>'
	);
}

my @argus;
foreach (url_param()) { if ($_ ne 'lang') { push(@argus, $_.'='.url_param($_)) } }

my $logo = a({-href=>"$url?db=$xbase&page=home&lang=$xlang", -style=>'text-decoration: none;'}, img({-src=>$docpath.'logoFLOW.png', -alt=>"FLOW", -style=>'border: 0;', -height=>'46px'}));

#$logo .= ' &nbsp;'.a({-href=>"http://www.charliehebdo.fr/index.html", -style=>'text-decoration: none;'}, img({-src=>$docpath.'jsc.png', -alt=>"Charlie Hebdo", -style=>'border: 0;', -height=>'46px'}));

my @dd = ('none') x 6;
my @langs = ('en','fr','es','de','zh','pt');
my $i = 0;
foreach (@langs) {
	if ($xlang eq $_) { $dd[$i] = 'block'; last; }
	$i++;
}

my $flags = 	span( {	-class=>'reactiveFlags',
			-id=>'en',
			-style=>"display: $dd[0];",
			-onMouseOver=>"this.style.cursor = 'pointer'; magicFlags('reactiveFlags', 'onMouseOver', '$xlang');",
			-onMouseOut=>"magicFlags('reactiveFlags', 'onMouseOut', '$xlang');",
			-onClick=>"	document.searchform.action = '$url?".join('&',@argus)."&lang=en';
					document.getElementById('searchpop').value = '$searchtable';
					document.getElementsByName('searchid')[0].value = '$searchid';
					document.getElementById('$searchtable').value = '$search';
					document.searchform.submit();"},
			img({-src=>$docpath.'en.gif', -alt=>"English", -width=>22, -border=>0})
		).
		span( {	-class=>'reactiveFlags',
			-id=>'fr',
			-style=>"display: $dd[1];",
			-onMouseOver=>"this.style.cursor = 'pointer'; magicFlags('reactiveFlags', 'onMouseOver', '$xlang');",
			-onMouseOut=>"magicFlags('reactiveFlags', 'onMouseOut', '$xlang');",
			-onClick=>"	document.searchform.action = '$url?".join('&',@argus)."&lang=fr';
					document.getElementById('searchpop').value = '$searchtable';
					document.getElementsByName('searchid')[0].value = '$searchid';
					document.getElementById('$searchtable').value = '$search';
					document.searchform.submit();"},
			img({-src=>$docpath.'fr.gif', -alt=>"French", -width=>22, -border=>0})
		).
		span( {	-class=>'reactiveFlags',
			-id=>'es',
			-style=>"display: $dd[2];",
			-onMouseOver=>"this.style.cursor = 'pointer'; magicFlags('reactiveFlags', 'onMouseOver', '$xlang');",
			-onMouseOut=>"magicFlags('reactiveFlags', 'onMouseOut', '$xlang');",
			-onClick=>"	document.searchform.action = '$url?".join('&',@argus)."&lang=es';
					document.getElementById('searchpop').value = '$searchtable';
					document.getElementsByName('searchid')[0].value = '$searchid';
					document.getElementById('$searchtable').value = '$search';
					document.searchform.submit();"},
			img({-src=>$docpath.'es.png', -alt=>"Spanish", -width=>22, -border=>0})
		).
		span( {	-class=>'reactiveFlags',
			-id=>'de',
			-style=>"display: $dd[3];",
			-onMouseOver=>"this.style.cursor = 'pointer'; magicFlags('reactiveFlags', 'onMouseOver', '$xlang');",
			-onMouseOut=>"magicFlags('reactiveFlags', 'onMouseOut', '$xlang');",
			-onClick=>"	document.searchform.action = '$url?".join('&',@argus)."&lang=de';
					document.getElementById('searchpop').value = '$searchtable';
					document.getElementsByName('searchid')[0].value = '$searchid';
					document.getElementById('$searchtable').value = '$search';
					document.searchform.submit();"},
			img({-src=>$docpath.'de.png', -alt=>"German", -width=>22, -border=>0})
		).
		span( {	-class=>'reactiveFlags',
			-id=>'zh',
			-style=>"display: $dd[4];",
			-onMouseOver=>"this.style.cursor = 'pointer'; magicFlags('reactiveFlags', 'onMouseOver', '$xlang');",
			-onMouseOut=>"magicFlags('reactiveFlags', 'onMouseOut', '$xlang');",
			-onClick=>"	document.searchform.action = '$url?".join('&',@argus)."&lang=zh';
					document.getElementById('searchpop').value = '$searchtable';
					document.getElementsByName('searchid')[0].value = '$searchid';
					document.getElementById('$searchtable').value = '$search';
					document.searchform.submit();"},
			img({-src=>$docpath.'zh.png', -alt=>"Chinese", -width=>22, -border=>0})
		).
		span( {	-class=>'reactiveFlags',
			-id=>'pt',
			-style=>"display: $dd[5];",
			-onMouseOver=>"this.style.cursor = 'pointer'; magicFlags('reactiveFlags', 'onMouseOver', '$xlang');",
			-onMouseOut=>"magicFlags('reactiveFlags', 'onMouseOut', '$xlang');",
			-onClick=>"	document.searchform.action = '$url?".join('&',@argus)."&lang=pt';
					document.getElementById('searchpop').value = '$searchtable';
					document.getElementsByName('searchid')[0].value = '$searchid';
					document.getElementById('$searchtable').value = '$search';
					document.searchform.submit();"},
			img({-src=>$docpath.'br.png', -alt=>"Portuguese", -width=>22, -border=>0})
		).
		div({-style=>'text-align: center;', -onMouseOver=>"this.style.cursor = 'pointer'; magicFlags('reactiveFlags', 'onMouseOver', '$xlang');", -onMouseOut=>"magicFlags('reactiveFlags', 'onMouseOut', '$xlang');"},
			img({-src=>$docpath.'triangle.png'})
		);	

my $icons = 	div({-class=>'info', -id=>"families", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'families'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=families&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'families');", -onMouseOut=>"document.getElementById('families').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/Fam.png', -alt=>"Families", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"genera", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'genera'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=genera&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'genera');", -onMouseOut=>"document.getElementById('genera').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/Gen.png', -alt=>"Genera", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"speciess", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'speciess'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=speciess&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'speciess');", -onMouseOut=>"document.getElementById('speciess').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/Spe.png', -alt=>"Species", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"names", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'names'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=names&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'names');", -onMouseOut=>"document.getElementById('names').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/Nam.png', -alt=>"Names", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"vernaculars", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'vernaculars'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=vernaculars&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'vernaculars');", -onMouseOut=>"document.getElementById('vernaculars').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/Ver.png', -alt=>"Vernacular names", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"publications", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'publications'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=publications&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'publications');", -onMouseOut=>"document.getElementById('publications').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/pub.png', -alt=>"Publications", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"authors", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'authors'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=authors&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'authors');", -onMouseOut=>"document.getElementById('authors').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/author.png', -alt=>"Authors", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"countries", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'countries'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=countries&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'countries');", -onMouseOut=>"document.getElementById('countries').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/world.png', -alt=>"Geographical distribution", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"associates", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'bioInteract'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=associates&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'associates');", -onMouseOut=>"document.getElementById('associates').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/plant.png', -alt=>"Associated taxa", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"fossils", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'fossils'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=cavernicolous&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'cavernicolous');", -onMouseOut=>"document.getElementById('cavernicolous').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/carvernicolous.png', -alt=>"Cavernicolous", -class=>'icon1'})). ' '.
        div({-class=>'info', -id=>"cavernicolous", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'cavernicolous'}->{$xlang})).
        a({-href=>$url."?db=$xbase&page=explorer&card=fossils&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'fossils');", -onMouseOut=>"document.getElementById('fossils').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/ere.png', -alt=>"Fossils", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"images", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'images'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=images&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'images');", -onMouseOut=>"document.getElementById('images').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/photos.png', -alt=>"Images", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"repositories", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'repositories'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=repositories&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'repositories');", -onMouseOut=>"document.getElementById('repositories').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/deposit.png', -alt=>"Type specimens repositories", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"board", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'board'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&lang=$xlang&card=board", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'board');", -onMouseOut=>"document.getElementById('board').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/synopsis.png', -alt=>"Synopsis", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"updates", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'lastUpdates'}->{$xlang})).
		a({	-href=>$url."?db=$xbase&page=explorer&lang=$xlang&card=updates", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'updates');", -onMouseOut=>"document.getElementById('updates').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/updates.png', -alt=>"Updates", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"classif", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'classification'}->{$xlang})).
        a({	-href=>$url."?db=$xbase&page=explorer&card=classification&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'classif');", -onMouseOut=>"document.getElementById('classif').style.display = 'none';"} , img({-src=>$docpath.'/wheel/img/logo_classif.png', -alt=>"Classification", -class=>'icon1'})).' '.
        div({-class=>'info', -id=>"molecular", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'molecular_data'}->{$xlang})).
        a({	-href=>$url."?db=$xbase&page=explorer&card=molecular&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'molecular');", -onMouseOut=>"document.getElementById('molecular').style.display = 'none';"} , img({-src=>$docpath.'/wheel/img/molecule_flow.png', -alt=>"Molecular data", -class=>'icon1'})). ' ';

#my $icons2 = 	p({-style=>'margin: 0 0 3px 0;'}, a({-href=>"$url?db=$xbase&page=project&lang=$xlang", -style=>'text-decoration: none;'}, img({-src=>$docpath.'wheel/img/project.png', -alt=>"Project", -class=>'icon2'}))).
#		p({-style=>'margin: 0 0 3px 0;'}, a({-href=>"$url?db=$xbase&page=intro&lang=$xlang", -style=>'text-decoration: none;'}, img({-src=>$docpath.'wheel/img/fulgo.png', -alt=>"Fulgoromorpha", -class=>'icon2'})));
#		p({-style=>'margin: 0 0 3px 0;'}, a({-href=>"classif.pl", -style=>'text-decoration: none;'}, img({-src=>$docpath.'wheel/img/classif.png', -alt=>"Classification", -class=>'icon2'})));


#if (url_param('test')) { 
#$test = "$searchid, $searchtable"; 
#}
my $msgbody = 
"Thank you for using FLOW. You want to report a problem with this page or you want to complete the data: any complementary information/data and correction are very welcome, but only published ones can be considered. 
So please provide the references of your sources. ";
# %0D%0A
if ($searchid) { 
	$msgbody .= " - ".url()."?db=flow;page=explorer;card=searching;searchid=$searchid;searchtable=noms_complets;lang=en;reload=1";
}
else { 
	$msgbody .= url(-path_info=>1,-query=>1);
}


my $icons2 =	div({-class=>'info', -id=>"contact", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'contact'}->{$xlang})).
		a({	-target=>'_blank', -href=>'mailto:thierry.bourgoin@mnhn.fr?'."subject=FLOW improvement&body=$msgbody", -style=>'text-decoration: none;',
			-onMouseOver=>"makeBulle(this, 'contact');", -onMouseOut=>"document.getElementById('contact').style.display = 'none';"}, 
			img({-src=>$docpath.'wheel/img/contact.png', -alt=>"contact", -class=>'icon1'})).
		div({-class=>'info', -id=>"projectFLOW", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'aboutProject'}->{$xlang})).
		a({	-href=>"$url?db=$xbase&page=project&lang=$xlang", -style=>'text-decoration: none;',
			-onMouseOver=>"document.getElementById('projectFLOW').style.display = 'block';", -onMouseOut=>"document.getElementById('projectFLOW').style.display = 'none';"}, 
			img({-src=>$docpath.'wheel/img/project.png', -alt=>"Project", -class=>'icon1'})).	
		div({-class=>'info', -id=>"fulgoromorpha", -style=>'position: absolute; z-index: 10; display: none;'}, 'Fulgoromorpha').
		a({	-href=>"$url?db=$xbase&page=intro&lang=$xlang", -style=>'text-decoration: none;',
			-onMouseOver=>"document.getElementById('fulgoromorpha').style.display = 'block';", -onMouseOut=>"document.getElementById('fulgoromorpha').style.display = 'none';"}, 
			img({-src=>$docpath.'wheel/img/fulgo.png', -alt=>"Fulgoromorpha", -class=>'icon1'}));

my $sb = start_form(    -name=>'searchform',
			-method=>'post',
			-action=>url()."?db=$xbase&page=explorer&card=searching&lang=$xlang",
			-class=>'searchForm'
	).
	table({-id=>'searchTable', -cellspacing=>0, -cellpadiing=>0},
		Tr(
			td({-style=>'height: 24px; margin: 0; padding-left: 6px; vertical-align: middle;'},
				a({-href=>"$url?".join('&',@argus)."&lang=$xlang&reload=1", -style=>'text-decoration: none;'}, img({-src=>$docpath.'wheel/img/reload.png', -alt=>"English", -width=>20, -border=>0}))
			),
			td({-style=>'height: 24px; padding-left: 4px; vertical-align: middle;'},
			#	div({-class=>"searchTitle"}, ucfirst($traduction->{search}->{$xlang}) )
			' '
			),
			td({-style=>'height: 24px; margin: 0; padding: 0; vertical-align: middle;'}, 	
				popup_menu(
					-name=>'searchtable',
					-class=>'searchPopup',
					-id=>'searchpop',
					-values=>[sort {$types{$a} cmp $types{$b}} keys(%types)],
					-default=> $typdef,
					-labels=>\%types,
					-attributes=>\%attributes,
					-onChange=>"clear_search_except('popup', this.value);"
				)
			),
			td({-style=>'width: 180px; height: 24px; margin: 0; padding: 0; vertical-align: top;'},
				span ({-style=>'position: absolute; margin: 0; padding: 0;'},
					$search_fields
				)
			)
		)
	).
	hidden('searchid', '').
	end_form();

## AFFICHAGE !!! ##########################################
my $arrow;

Delete('hiddensearch');

#my $twit =<<EOS;
#<a href="https://twitter.com/FLOWwebsite" class="twitter-follow-button" data-show-count="false"></a>
#<script>!function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0],p=/^http:/.test(d.location)?'http':'https';if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src=p+'://platform.twitter.com/widgets.js';fjs.parentNode.insertBefore(js,fjs);}}(document, 'script', 'twitter-wjs');</script>
#EOS

my $twit = '<a href="https://twitter.com/FLOWwebsite" target="_blank">'.img({-src=>$docpath."twiter.png", alt=>"Twitter", height=>'20px'}).'</a>';
my $fcbk = '<a href="https://www.facebook.com/FLOWwebsite" target="_blank">'.img({-src=>$docpath."facebook.png", alt=>"Facebook", height=>'20px'}).'</a>';

	print	$header;
	#print	$test;
	print	"<DIV id='main_container'>";
	print	"		<TABLE id='iconsSearchbar'>";
	print	"			<TR>";
	print	"				<TD ID=logoCell rowspan=2> $logo </TD>";
	print	"				<TD rowspan=2>";
	print	"					<TABLE><TR><TD colspan=2 style='height: 16px; font-size: 11px; vertical-align:text-top;'> $traduction->{'followFLOW'}->{$xlang} FLOW:</TD></TR>";
	print	"					<TR><TD>$twit</TD><TD>$fcbk</TD></TR></TABLE>";
	print	"				</TD>";
	print	"				<TD CLASS='iconsCell'> $icons </TD>";
	print	"				<TD> $icons2 </TD>";
	print	"				<TD id='flagsCell'>";
	print						div ({-id=>'flagsDiv'}, $flags);
	print	"				</TD>";
	#print	"				<TD id='moreFlagsCell'>";
	#print							img({	-src=>'moreFlags.png',
    #									-id=>'moreFlagsImg',
	#								-onMouseOver=>"magicFlags('reactiveFlags', 'onMouseOver', '$xlang');",
	#								-onMouseOut=>"this.style.cursor='pointer'; magicFlags('reactiveFlags', 'onMouseOut', '$xlang');"});
	#print	"				</TD>";
	print	"			</TR>";
	print	"			<TR>";
	print	"				<TD ID='searchCell' colspan=2>";
	print	"					<TABLE><TR><TD ID='searchPill'> $sb </TD></TR></TABLE>";
	print	"				</TD>";
	print	"			</TR>";
	print	"		</TABLE>";
	
	#if ($xpage ne 'explorer') {
	#	print	"	<TABLE id='leftIcons'>";
	#	print	"		<TR>";
	#	print	"			<TD id='projectCell'>";
	#	print	"				$icons2";
	#	print	"			</TD>";
	#	print	"		</TR>";
	#	print "		</TABLE>";
	#}

	print $content;
	if ($xpage eq 'explorer' and !url_param('loading')) {
		print "<DIV class='contentContainer'>";
		system $script;
		print "</DIV>";
	}
	
	my $sm1 = a({-target=>'_blank', -href=>'mailto:bourgoin@mnhn.fr?'."subject=FLOW improvement&body=$msgbody", -style=>'text-decoration: none;'}, ucfirst($traduction->{'contact'}->{$xlang}));
	my $sm2 = a({-href=>"$url?db=$xbase&page=project&lang=$xlang", -style=>'text-decoration: none;'}, ucfirst($traduction->{'aboutProject'}->{$xlang}));	
	my $sm3 = a({-href=>"$url?db=$xbase&page=intro&lang=$xlang", -style=>'text-decoration: none;'}, 'Fulgoromorpha');
	my $sm4 = a({-href=>$url."?db=$xbase&page=explorer&card=families&lang=$xlang", -style=>'text-decoration: none;'}, ucfirst($traduction->{'families'}->{$xlang}));
	my $sm5 = a({-href=>$url."?db=$xbase&page=explorer&card=genera&lang=$xlang", -style=>'text-decoration: none;'}, ucfirst($traduction->{'genera'}->{$xlang}));
	my $sm6 = a({-href=>$url."?db=$xbase&page=explorer&card=speciess&lang=$xlang", -style=>'text-decoration: none;'}, ucfirst($traduction->{'speciess'}->{$xlang}));
	my $sm7 = a({-href=>$url."?db=$xbase&page=explorer&card=names&lang=$xlang", -style=>'text-decoration: none;'}, ucfirst($traduction->{'names'}->{$xlang}));
	my $sm8 = a({-href=>$url."?db=$xbase&page=explorer&card=vernaculars&lang=$xlang", -style=>'text-decoration: none;'}, ucfirst($traduction->{'vernaculars'}->{$xlang}));
	my $sm9 = a({-href=>$url."?db=$xbase&page=explorer&card=publications&lang=$xlang", -style=>'text-decoration: none;'}, ucfirst($traduction->{'publications'}->{$xlang}));
	my $sm10 = a({-href=>$url."?db=$xbase&page=explorer&card=authors&lang=$xlang", -style=>'text-decoration: none;'}, ucfirst($traduction->{'authors'}->{$xlang}));
	my $sm11 = a({-href=>$url."?db=$xbase&page=explorer&card=countries&lang=$xlang", -style=>'text-decoration: none;'}, ucfirst($traduction->{'countries'}->{$xlang}));
	my $sm12 = a({-href=>$url."?db=$xbase&page=explorer&card=associates&lang=$xlang", -style=>'text-decoration: none;'}, ucfirst($traduction->{'bioInteract'}->{$xlang}));
	my $sm13 = a({-href=>$url."?db=$xbase&page=explorer&card=fossils&lang=$xlang", -style=>'text-decoration: none;'}, ucfirst($traduction->{'fossils'}->{$xlang}));
	my $sm14 = a({-href=>$url."?db=$xbase&page=explorer&card=images&lang=$xlang", -style=>'text-decoration: none;'}, ucfirst($traduction->{'images'}->{$xlang}));
	my $sm15 = a({-href=>$url."?db=$xbase&page=explorer&card=repositories&lang=$xlang", -style=>'text-decoration: none;'}, ucfirst($traduction->{'repositories'}->{$xlang}));
	my $sm16 = a({-href=>$url."?db=$xbase&page=explorer&lang=$xlang&card=board", -style=>'text-decoration: none;'}, ucfirst($traduction->{'board'}->{$xlang}));
	my $sm17 = a({-href=>$url."?db=$xbase&page=explorer&lang=$xlang&card=updates", -style=>'text-decoration: none;'}, ucfirst($traduction->{'lastUpdates'}->{$xlang}));
	my $sm18 = a({-href=>"http://hemiptera.infosyslab.fr/flow/", -style=>'text-decoration: none;'}, 'FLOW');	
#	my $sm18 = a({-href=>"http://hemiptera.infosyslab.fr/flow/", -style=>'text-decoration: none;'}, 'FLOW');	
	my $sm19 = a({-href=>"http://hemiptera.infosyslab.fr/", -style=>'text-decoration: none;', -target=>"_blank"}, 'HemDBases');	
#	my $sm19 = a({-href=>"http://hemiptera.infosyslab.fr/", -style=>'text-decoration: none;', -target=>"_blank"}, 'HemDBases');	
	my $sm20 = a({-href=>"http://hemiptera.infosyslab.fr/dbtnt/", -style=>'text-decoration: none;', -target=>"_blank"}, 'DBTNT');	
#	my $sm20 = a({-href=>"http://hemiptera.infosyslab.fr/dbtnt/", -style=>'text-decoration: none;', -target=>"_blank"}, 'DBTNT');	
	my $sm21 = '<a href="https://twitter.com/FLOWwebsite" target="_blank">Twitter</a>';
	my $sm22 = '<a href="https://www.facebook.com/FLOWwebsite" target="_blank">Facebook</a>';
	my $sm23 = a({-href=>$url."?db=$xbase&page=explorer&card=moleculardata&lang=$xlang", -style=>'text-decoration: none;'}, ucfirst($traduction->{'molecular_data'}->{$xlang}));

	# Footer links update by vannicknonongo@gmail.com

	my $sm24 = a({-href=>$url."?db=$xbase&page=explorer&card=classification&lang=$xlang", -style=>'text-decoration: none;'}, ucfirst($traduction->{'linnean_classification'}->{$xlang}));
	my $sm25 = a({-href=>"#", -style=>'text-decoration: none;'}, ucfirst($traduction->{'phylogeny'}->{$xlang}));

	print br.div({-class=>'card', -style=>'background: #DDDDDD; margin-left: 10px;'}, 
			table({style=>'width: 100%; /*table-layout: fixed;*/ font-size: 12px; line-height: 10px;'}, 
			Tr(td('&nbsp;')),
			Tr(
				td({style=>'vertical-align: top;'}, ul({style=>'text-align: left; margin-left: 15px;'}, li({-style=>'padding-bottom: 3px;'}, b('Home')), li($sm18), li($sm19), li($sm20))),
				td({style=>'vertical-align: top;'}, ul({style=>'text-align: left;'}, li({-style=>'padding-bottom: 3px;'}, b('Taxonomy')), li($sm4), li($sm5), li($sm6))),
				td({style=>'vertical-align: top;'}, ul({style=>'text-align: left;'}, li({-style=>'padding-bottom: 3px;'}, b('Names')), li($sm7), li($sm8))),
				td({style=>'vertical-align: top;'}, ul({style=>'text-align: left;'}, li({-style=>'padding-bottom: 3px;'}, b('Classifications')), li($sm24), li($sm25))),
				td({style=>'vertical-align: top;'}, ul({style=>'text-align: left;'}, li({-style=>'padding-bottom: 3px;'}, b('Associated data')), li($sm23), li($sm11), li($sm12), li($sm13), li($sm14), li($sm15))),
				td({style=>'vertical-align: top;'}, ul({style=>'text-align: left;'}, li({-style=>'padding-bottom: 3px;'}, b('Bibliography')), li($sm9), li($sm10))),
				td({style=>'vertical-align: top;'}, ul({style=>'text-align: left;'}, li({-style=>'padding-bottom: 3px;'}, b('General')), li($sm2), li($sm3), li($sm16), li($sm17))),
				td({style=>'vertical-align: top;'}, ul({style=>'text-align: left;'}, li({-style=>'padding-bottom: 3px;'}, b('Follow FLOW')), li($sm21), li($sm22), li($sm1)))

			),
			Tr(td('&nbsp;')),
			)
	);
	print	"</DIV>";

print	end_html();
#print hide_progress_bar;

$dbc->disconnect;

exit;

sub search_formating {
	my ($table, $arr, $thesaur, $load, $dbh) = @_;
			
	my $ids;
	my $values;
	my $authors = [];
	foreach (@{$arr}) {
		$_->[1] =~ s/'/\\'/g;
		$_->[1] =~ s/"/\\"/g;
		$_->[1] =~ s/\[/\\[/g;
		$_->[1] =~ s/\]/\\]/g;
		$_->[1] =~ s/  / /g;
		
		push(@{$ids}, $_->[0]);
		push(@{$values}, $_->[1]);
		
		if ($table ne 'noms_complets') {
			if ($_->[1] =~ m|[^A-Z a-z 0-9 : , ( ) \[ \] ! _ = & Â° . * ; â€œ "Ã© â€™ â€� Ã©' \\ \/ \- â€“ ? â€¡ \n ]|) {
				my ($res) = @{request_row("SELECT reencodage('".$_->[1]."');", $dbh)};
				$res =~ s/'/\\'/g;
				$res =~ s/"/\\"/g;
				$res =~ s/\[/\\[/g;
				$res =~ s/\]/\\]/g;
				$res =~ s/  / /g;
				
				push(@{$ids}, $_->[0]);
				push(@{$values}, $res);
			}	
		}
		else {
			$_->[2] =~ s/'/\\'/g;
			$_->[2] =~ s/"/\\"/g;
			$_->[2] =~ s/\[/\\[/g;
			$_->[2] =~ s/\]/\\]/g;
			$_->[2] =~ s/  / /g;
			push(@{$authors}, $_->[2]);
		}
	}
	${$thesaur} .= $table . "ids = ['" . join("','", @{$ids}) . "']; $table = ['" . join("','", @{$values}) . "']; ";
	if ($table eq 'noms_complets') {
		${$thesaur} .= "authors = ['" . join("','", @{$authors}) . "']; ";
		${$load} .= "AutoComplete_Create('$table', $table, $table"."ids, authors, 10);";
	}
	else {
		${$load} .= "AutoComplete_Create('$table', $table, $table"."ids, '', 10);";
	}
}

sub read_lang {
	my ( $conf ) = @_;
	my $tr = { };
	my $rdbms  = $conf->{TRAD_RDBMS};
	my $server = $conf->{TRAD_SERVER};
	my $db     = $conf->{TRAD_DB};
	my $port   = $conf->{TRAD_PORT};
	my $login  = $conf->{TRAD_LOGIN};
	my $pwd    = $conf->{TRAD_PWD};
	my $webmaster = $conf->{TRAD_WMR};
	if ( my $dbc = DBI->connect("DBI:$rdbms:dbname=$db;host=$server;port=$port", $login, $pwd) ){
		$tr = $dbc->selectall_hashref("SELECT id, $xlang FROM traductions;", "id");
		$dbc->disconnect;
		return $tr;
	}
	else {
		my $error_msg .= $DBI::errstr;
		print 	header('Error'),
			h1("Database connection error"),
			pre($error_msg),p;

		return undef;
	}
}

sub classification {
	
	my $conf = get_connection_params('/etc/flow/classif.conf');
	
	my $dbh = db_connection($conf);
	
	my $trans = read_lang($conf);
	
	my $order = request_tab("SELECT n.index, orthographe, fossil FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE r.en = 'order';", $dbh, 2);
	my $classif .= span({-style=>'margin-left: 20px;'},$order->[0][1]) . br;
	
	my $suborders = request_tab("SELECT n.index, orthographe, fossil FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE n.ref_nom_parent = $order->[0][0] ORDER BY orthographe;", $dbh, 2);
	
	foreach my $suborder (@{$suborders}) {
	
		my $nom = $suborder->[1];
		
		if ($suborder->[2]) { $nom .= 'Â†' }
		
		$classif .= span({-style=>'margin-left: 40px;'},$nom) . br;
		
		my $infraorders = request_tab("SELECT n.index, orthographe, fossil, r.en FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE n.ref_nom_parent = $suborder->[0] ORDER BY orthographe;", $dbh, 2);
		
		foreach my $infraorder (@{$infraorders}) {
		
			if ($infraorder->[3] eq 'infraorder') {
				
				$nom = $infraorder->[1];
				
				if ($infraorder->[2]) { $nom .= 'Â†' }
				
				$classif .= span({-style=>'margin-left: 60px;'},$nom) . br;
				
				my $sons = request_tab("SELECT n.index, orthographe, fossil, r.en FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE n.ref_nom_parent = $infraorder->[0] ORDER BY orthographe;", $dbh, 2);
				
				foreach my $son (@{$sons}) {
				
					if ($son->[3] eq 'super family') {
						
						$nom = $son->[1];
						
						if ($son->[2]) { $nom .= 'Â†' }
						
						$classif .=span({-style=>'margin-left: 80px;'},$nom) . br;
						
						my $families = request_tab("SELECT n.index, orthographe, fossil, r.en FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE n.ref_nom_parent = $son->[0] ORDER BY orthographe;", $dbh, 2);
						
						foreach my $family (@{$families}) {
							
							$nom = $family->[1];
							
							if ($family->[2]) { $nom .= 'Â†' }
							
							$classif .= span({-style=>'margin-left: 100px;'},$nom) . br;
						}
					}
					elsif ($son->[3] eq 'family') {
						
						$nom = $son->[1];
						
						if ($son->[2]) { $nom .= 'Â†' }
						
						$classif .= span({-style=>'margin-left: 100px;'},$nom) . br;
					}
				}
			}
			elsif ($infraorder->[3] eq 'super family') {
				
				$nom = $infraorder->[1];
				
				if ($infraorder->[2]) { $nom .= 'Â†' }
				
				$classif .= span({-style=>'margin-left: 80px;'},$nom) . br;
				
				my $families = request_tab("SELECT n.index, orthographe, fossil, r.en FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE n.ref_nom_parent = $infraorder->[0] ORDER BY orthographe;", $dbh, 2);
			
				foreach my $family (@{$families}) {
					
					$nom = $family->[1];
					
					if ($family->[2]) { $nom .= 'Â†' }
					
					$classif .= span({-style=>'margin-left: 100px;'},$nom) . br;
				}
			}
		}
	}
	
	$classif .= p . span({-style=>'margin-left: 20px;'},"Incertae sedis") . br;
				
	my $incertae = request_tab("SELECT n.index, orthographe, fossil FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE r.en = 'incertae sedis' ORDER BY orthographe;", $dbh, 2);
	
	foreach my $insed (@{$incertae}) {
		
		my $nom = $insed->[1];
		
		if ($insed->[2]) { $nom .= 'Â†' }
		
		$classif .= span({-style=>'margin-left: 40px;'},$nom) . br;
	}
			
	my $content = h2({-style=>'margin-left: 20px'}, "Hemiptera classification"). br. $classif;
}
