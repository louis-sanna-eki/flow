
/* This script and many more are available free online at
The JavaScript Source :: http://javascript.internet.com
Created by: Timothy Groves :: http://www.brandspankingnew.net/ */

authors = new Array("Anta Angel","Odent Aurélien", "Fauvre Laurent");

var sug = "";
var sug_disp = "";

function getAuthor() {
  var input = document.forms['address_frm'].author.value;
  var len = input.length;
  sug_disp = ""; sug = "";
  
  if (input.length) {
    // get matching author from array
    for (ele in authors)
    {
      if (authors[ele].substr(0,len).toLowerCase() == input.toLowerCase())
      {
        sug_disp = input + authors[ele].substr(len);
        sug = authors[ele];
        break;
      }
    }
  } 
  document.forms['address_frm'].sug_author.value = sug_disp;
  if (!sug.length || input == sug_disp)
    document.getElementById('sug_btn').style.display = "none";
  else
    document.getElementById('sug_btn').style.display = "block";
}

function setAuthor() {
  document.forms['address_frm'].author.value = sug;
  hideSug();
}

function hideSug() {
  document.forms['address_frm'].sug_author.value = "";
  document.getElementById('sug_btn').style.display = "none";
}



<!-- Paste this code into the HEAD section of your HTML document.
     You may need to change the path of the file.  -->

<script type="text/javascript" src="autoComplete.js"></script>



<!-- Paste this code into the BODY section of your HTML document  -->

<div style="width: 202px; margin: 100px auto 0 auto;">
<form name="address_frm">
  <div>Search for a destination:</a>
  <div style="position: relative; margin: 5px 0 5px 0; height: 30px;">
  <div style="position: absolute; top: 0; left: 0; width: 200px; z-index: 1;">
    <input type="text" name="sug_author" style="background-color: #fff; border: 1px solid #999; width: 200px; padding: 2px" disabled />
  </div>
  <div style="position: absolute; top: 0; left: 0; width: 200px; z-index: 2;">
    <input autocomplete="off" type="text" name="author" style="background: none; color:#39f; border: 1px solid #999; width: 200px; padding: 2px" onfocus="getAuthor()" onkeyup="getAuthor()" />
  </div>
    <div id="sug_btn" style="position: absolute; top: 5px; right: 5px; z-index: 3; display: none;">
        <a href="#" onclick="setAuthor()"><img src="img/mi_arr2_left.gif" width="10" height="10" border="0" align="textbottom"></a>
      </div>
  </div>
</form>
</div>
</div>
<p><div align="center">
<font face="arial, helvetica" size"-2">Free JavaScripts provided<br>
by <a href="http://javascriptsource.com">The JavaScript Source</a></font>
</div><p>
