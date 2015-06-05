# Cologne-Sanskrit-Tamil
A port of http://www.sanskrit-lexicon.uni-koeln.de/scans/MWScan/tamil/index.html.

The 'Sanskrit and Tamil Dictionaries' is a web application created c. 2003 by
Thomas Malten (who supplied the digitized dictionaries) and Kira Stöwe (who
programmed the display) .  

This repository contains all the programs and data required to run this
application on an appropriate web server.

This has been tested on a computer with Windows Vista operating system 
running the XAMPP web server.

## How to install on Windows computer with XAMPP
Experienced users will know various other ways to install this application.
It is a Perl cgi web application.
Here are details of one way to install.

* download the ZIP of this of this repository, about 22 mb
  * Unzip this to folder which will be named 
    Cologne-Sanskrit-Tamil-master;  the files in this folder are
    directories `dat` and `sqlite`, programs `recherche.pl` and 
    `cgi-include.pl`, web page `index.html` and a couple of other files.,
    
* Install XAMPP for a Windows computer into C:\xampp directory
* move the Cologne-Sanskrit-Tamil-master folder into the 
  C:\xampp\htdocs folder.
* Open the XAMPP COntrol Panel, and start the `Apache module`.
* Open a browser, and enter the url
  http://localhost/cologne/legacy/index.html
* Now the **Sanskrit and Tamil Dictionaries** display should be functioning.

## Programming notes
* The two Perl modules used for the application are recherche.pl and 
  cgi-include2.pl.  Consistent with XAMPP conventions, these are not
  put into a separate 'cgi-bin' location, but are in the same directory
  as index.html.  recherche.pl is the Perl module referenced as the
  value of the 'action' parameter of the 'form' element in index.html.
* The first line of these Perl modules reference the Perl executable as
  #!"C:\xampp\perl\bin\perl.exe"; this is appropriate for XAMPP.
* The dictionary data is accessed via the sqlite/tamil.sqlite database.
  This is a sqlite3 database, initialized from the ganz.txt file.  
  ganz.txt contains data for all the dictionaries in the form of 
  lines of 3 tab-delimited fields: 
  * dictionary id  1,2,or 3. Data for a 4th dictionary (Pahlavi) is unused
    in the display.
  * headword
  * entry
* The batch file redo.bat in sqlite directory recreates the sqlite3 
  database tamil.sqlite.  This uses the sqlite3.exe included in XAMPP.
  def.sql is the file that governs the creation of the 'tamil' table and
  the loading of ganz.txt into the tamil table.
* The search-engine of recherech.pl operates roughly as follows:
  * from the words and search options (exact, substring, prefix) of the
    Search input form, an sql query is formed.  
  * This sql query is processed by the database (sqlite3) and results are
    returned and displayed on a separate page.
* In the Cologne version, the data is in a MySQL database; the sql query is
  slightly different for sqlite3 database.  
* Initial examination suggests that the Cologne display and this XAMPP/sqlite3
  port are almost, though not exactly, identical.

## License request
If you install this on any public server, please add a notice that the 
data source is from http://www.sanskrit-lexicon.uni-koeln.de/, or reference
this repository https://github.com/sanskrit-lexicon/Cologne-Sanskrit-Tamil.

If you install this display under different configurations, please consider
sharing the details of any changes required, so that others may benefit from
your experience.



