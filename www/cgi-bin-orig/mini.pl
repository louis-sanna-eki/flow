#!/usr/bin/perl

use CGI;

$cgi=new CGI;

print $cgi->header;
print $cgi->start_html('hello world !');
print $cgi->h1('hello world !');
print $cgi->end_html;


