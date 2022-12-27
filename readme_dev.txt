
These notes are somewhat obsolete as of 12/27/2022.
However, they may have some clues.
The entry point for the application is file php/index.html.
A very similar entry point is perl/index.html.
The php version is a very close port of the perl version.
The php version removes the 'all' option for 'Maximum Output'.

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
