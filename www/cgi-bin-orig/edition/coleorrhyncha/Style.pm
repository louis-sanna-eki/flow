package Style;

use Carp;
use strict;
use warnings;


BEGIN {
	use Exporter   ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	
	@ISA         = qw(Exporter);
	@EXPORT      = qw($background $rowcolor $css $conf_file $jscript_funcs $jscript_imgs $jscript_for_hidden $dblabel);
	%EXPORT_TAGS = ();
	
	# vos variables globales a etre exporter vont ici,
	# ainsi que vos fonctions, si necessaire
	@EXPORT_OK   = qw();
}
    

# Les globales non exportees iront la
use vars      qw($background $rowcolor $css $conf_file $jscript_imgs $jscript_for_hidden $dblabel);

# Initialisation de globales, en premier, celles qui seront exportees

our $background = '#FEF8E2';
our $rowcolor = '#FEF8E2';

our $dblabel = 'coleorrhyncha';

our $conf_file = '/etc/flow/pelorideditor.conf';


our $css = " 
	body {
		margin: 0;
		color: navy;
		font-family: Arial;
	}
	.wcenter {
		width: 1000px;
		margin: 0 auto;
	}
	.textNavy {
		color: navy;
	}
	.PopupStyle {
		background: #FFFFEE;
		color: navy;
		font-family: Arial;
		font-size: 12pt;
	}

	.popupTitle {
		background: #FFFFEE;
		color: navy;
		font-weight: bold;
		font-family: Arial;
		font-size: 12pt;
	}
	.textLarge { font-size: normal; }
	.phantomTextField {
		background: #FFFFEE; 
		color:navy; 
		border: 1px solid #999;
		padding-top: 4px;
		padding-left: 4px;
		padding-bottom: 2px;
		font-size: 12pt;
		font-family: Arial;
	}
	.pub_auteurs { font-variant: small-caps; font-size: 4; }
";

our $jscript_for_hidden = "
	
	function appendHidden (form, hidname, hidvalue) {
		Cfield = document.createElement('input');
		Cfield.setAttribute('type', 'hidden');
		Cfield.setAttribute('name', hidname);
		Cfield.setAttribute('value', hidvalue);
		form.appendChild(Cfield);
	}
	
	function removeHidden (form, hidden) {
		form.removeChild(hidden);
	}
";

our $jscript_imgs = "
		var okonimg = new Image ();
		var okoffimg = new Image ();
		okonimg.src = '/Editor/ok1.png';
		okoffimg.src = '/Editor/ok0.png';
		var newonimg = new Image ();
		var newoffimg = new Image ();
		newonimg.src = '/Editor/new1.png';
		newoffimg.src = '/Editor/new0.png';
		var backonimg = new Image ();
		var backoffimg = new Image ();
		backonimg.src = '/Editor/back1.png';
		backoffimg.src = '/Editor/back0.png';
		var modifonimg = new Image ();
		var modifoffimg = new Image ();
		modifonimg.src = '/Editor/modify1.png';
		modifoffimg.src = '/Editor/modify0.png';
		var mMonimg = new Image ();
		var mMoffimg = new Image ();
		mMonimg.src = '/Editor/mainMenu1.png';
		mMoffimg.src = '/Editor/mainMenu0.png';
		var chgonimg = new Image ();
		var chgoffimg = new Image ();
		chgonimg.src = '/Editor/Change1.png';
		chgoffimg.src = '/Editor/Change0.png';
		var searchonimg = new Image ();
		var searchoffimg = new Image ();
		searchonimg.src = '/Editor/search1.png';
		searchoffimg.src = '/Editor/search0.png';		
		var clearonimg = new Image ();
		var clearoffimg = new Image ();
		clearonimg.src = '/Editor/clear1.png';
		clearoffimg.src = '/Editor/clear0.png';";
