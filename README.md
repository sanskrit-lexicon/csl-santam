# csl-santam
<!--
A port of http://www.sanskrit-lexicon.uni-koeln.de/scans/MWScan/tamil/index.html.
-->

The 'Sanskrit and Tamil Dictionaries' is a web application created c. 2003 by
Thomas Malten (who supplied the digitized dictionaries) and Kira Stöwe (who
programmed the display) .  

This repository contains all the programs and data required to run this
application on an appropriate web server.

This has been tested on a computer with Windows 11  operating system 
running the XAMPP web server.

## How to install on Windows computer with XAMPP
Experienced users will know various other ways to install this application.
It is a php web application.
<!--\It is a Perl cgi web application. -->
Here are details of one way to install.

* clone this repository, about 22 mb
  * Unzip this to folder which will be named 
    Cologne-Sanskrit-Tamil-master;  the files in this folder are
    directories `dat` and `sqlite`, programs `recherche.pl` and 
    `cgi-include.pl`, web page `index.html` and a couple of other files.,
    
* Install XAMPP for a Windows computer into C:\xampp directory
* move the folder somewhere below the C:\xampp\htdocs folder.
  * for example: C:\xampp\htdocs\cologne\csl-santam
* Open the XAMPP COntrol Panel, and start the `Apache module`.
* Open a browser, and enter the url
  http://localhost/cologne/csl-santam/php
* Now the **Sanskrit and Tamil Dictionaries** display should be functioning.

See the readme_dev.txt file for some comments of possible relevance to developers.


## License request
If you install this on any public server, please add a notice that the 
data source is from http://www.sanskrit-lexicon.uni-koeln.de/, or reference
this repository https://github.com/sanskrit-lexicon/Cologne-Sanskrit-Tamil.

If you install this display under different configurations, please consider
sharing the details of any changes required, so that others may benefit from
your experience.



