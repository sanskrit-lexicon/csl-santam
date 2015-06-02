#!"C:\xampp\perl\bin\perl.exe"
#!/usr/bin/perl
#!/vol/perl/bin/perl
# 11.2.2003 SW: Recherche in der tamil-Datenbank 
# 12.8.2008 EJF: modified for sanskrit-lexicon website configuration
# 12.9.2008 EJF: omitted cpd (Concise Pahlavi Dictionary) at request of T. Malten
# 05.31.2015 EJF: Modify to work with sqlite3.
#   Testing was done with XAMPP server under Windows Vista.
print "Content-type: text/html\n\n";
do 'cgi-include2.pl';
$dictionary=$F{"dictionary"};
$st=$F{'st'}; $prst=$F{'prst'};
$en=$F{'en'}; $pren=$F{'pren'};
$maxhits=$F{'maxhits'} || 100;
#print "st=$st,prst=$prst,en=$en,pren=$pren<br>\n";
$dir="dat"; 
#%dict=(
#  'mwd' => "Cologne Digital Sanskrit Lexicon",
#  'cap' => "Capeller's Sanskrit-English Dictionary",
#  'otl' => "Cologne Online Tamil Lexicon",
#  'cpd' => "Concise Pahlavi Dictionary");
#$dictname=$dict{$dictionary} || &fehler (
#  "No dictonary has been selected.");

#%dict=('all'=>0, 'mwd'=>1, 'cap'=>2, 'otl'=>3, 'cpd'=>4);
#@dictshort=('all','mwd','cap','otl','cpd');
#@dict=("All dictionaries","Cologne Digital Sanskrit Lexicon",
#  "Capeller's Sanskrit-English Dictionary",
#  "Cologne Online Tamil Lexicon","Concise Pahlavi Dictionary");
&readbooks;
if ($dictionary eq 'all') {$dictnum=0}
else {defined ($dictnum=$dict{$dictionary}) || &fehler (
  "No dictonary has been selected.$dictionary")}
$dictname=$dict[$dictnum];

print
  "<html><head><title>$dictname: Search Results</title></head>\n",
  "<body bgcolor=\"#ffffff\">\n<h1>$dictname: Search Results</h1>\n";
#unless ($st || $en) {&fehler("No search has been formulated.")}
unless (($st && (length($st)>1)) || ($en && (length($en)>1))) {
  &fehler("No search has been formulated.")}
# $befehl="select id,st,en from $dictionary where ";
#EJF changed 'buch' to 'id' to agree with 'tamil' sql table
# EJF $where=$dictnum ? "id=$dictnum" : "";
$where=$dictnum ? "id=$dictnum" : "id<4";  # exclude cpd with id=4.
&where($st,'st',$prst);
&where($en,'en',$pren);
unless ($where) {&fehler ("No useable search has been formulated.")}
#$befehl="select id,st,en from tamil where $where order by st";
# 'collate nocase' needed in sqlite3, otherwise ordering is case sensitive.
$befehl="select id,st,en from tamil where $where order by st collate nocase";
#print "<p>dbg: sql=$befehl</p>\n";
#print "SQL query: $befehl \n <br>";
#print "data=$data<br>\nmaxhits=$maxhits";
#&opendb("webapps");
$dbh = opendb();
#print "back from opendb\n<br/>";
#$befehl = "select * from tamil where (st regexp 'rA') ";
#print "SQL query: $befehl \n <br>";
$sth=$dbh->prepare($befehl);
($sth->execute) || &fehler("Error $!\n".$sth->errstr);
#print "dictnum = $dictnum\n<br/>";
if (!$dictnum) {
  print "<table>\n";
  for ($i=1;$i<=$#dict;++$i) {print
    "<tr><td>($dictshort[$i]) </td><td>=</td><td> $dict[$i]</td></tr>\n"}
  print "</table><br>\n"}
print "<table cellspacing=3>";
$hitnr=0;
while (($id,$st,$en)=$sth->fetchrow_array) {
  last if (++$hitnr>$maxhits);
  $st=~s/^\. +//; $st=~s/ +\.$//; $en=~s/^\. +//; $en=~s/ +\.$//;
  $buchaus=$dictnum ? "" : "<td valign=top>($dictshort[$id])</td>";
  print "<tr><td align=right valign=top>$hitnr</td>\n",
    "$buchaus<td valign=top> <b>$st</b></td>\n",
    "<td valign=top>$en</td></tr>\n"}
print "</table>\n";
print "No entries found." unless $hitnr;
#print "hitnr = $hitnr\n<br/>";
print "</body></html>";
&closedb;

#------------------------
sub where {
# Error POSIX class [:<:] unknown in regex; marked by <-- HERE in m/[[:<:] <-- HERE ]deva[[:>:]]/ 
#------------------------
my ($var,$varname,$pr)=@_;
return unless $var;
$wb='[[:<:]]';   # word begin in regexp
$we='[[:>:]]';   # word end
$wb = "\\b"; # May 31, 2015.  For sqlite under XAMPP 
$we = "\\b";
for (split(/ +/,$var)) {
  next if $_ eq '';
  s/\\/\\\\/g; s/\'/\\\'/g; s/\%/\\\%/g;
  $where.=" and " if $where;
  #if ($pr eq "exact") {$where.="($varname like '% $_ %')"}
  #elsif ($pr eq "prefix") {$where.="($varname like '% $_%')"}
  $regexp = 'regexp';  # EJF prior code
  if ($pr eq "exact") {
    $where.="($varname $regexp '$wb$_$we')"}
  elsif ($pr eq "prefix") {
    $where.="($varname $regexp '$wb$_')"}
  else {$where.="($varname like '%$_%')"}}}

#------------------------
sub fehler {print "<h4>$_[0]</h4>\n</body></html>\n"; exit}
#------------------------
sub opendb { # EJF May 31, 2015. for 
# ignore dbname passed as argument
require DBI;
my  $dbh = DBI->connect ("DBI:SQLite:dbname=sqlite/tamil.sqlite","","")
             || die "Could not connect to database: "
             . DBI-> errstr;
#print "dbh = $dbh\n";
    return $dbh;

}
#------------------------
sub cologne_opendb { # EJF
# ignore dbname passed as argument
require DBI;
my  $dbh = DBI->connect ("DBI:SQLite:dbname=tamil.sqlite","","")
             || die "Could not connect to database: "
             . DBI-> errstr;
    my $dbname = "sanskrit-lexicon";
    my $dbpwd = "xxxxx";
    my  $dbh = DBI->connect ("DBI:mysql:sanskrit-lexicon:mysql.rrz.uni-koeln.de",
			 $dbname,$dbpwd)
             || die "Could not connect to database $dbname:  "
             . DBI-> errstr;
#print "dbh = $dbh\n";
    return $dbh;

}
#------------------------
sub old_opendb {
#------------------------
return if $DbOpened;
my $dbname=shift;
require DBI;
$defaults="/home/webapps/.my.cnf";
$dbdriver='mysql';
$dbsource="DBI:$dbdriver:$dbname;mysql_read_default_file=$defaults";
#print "dbsource=$dbsource<br>\n";
$DbOpened=1;
$dbh=DBI->connect($dbsource) || &fehler("No data base connection");}

#------------------------
sub closedb {
#------------------------
$sth->finish();
$dbh->disconnect()}

#------------
sub readbooks {
#------------
open (F,"<$dir/books") or &fehler ("no open (F,\"&lt;$dir/books\"):$!");
read (F,$books,10000);
close F;
# example line: 1 mwd Cologne Digital Sanskrit Lexicon
%dict=(0); @dict=(); @dictshort=();
for (split(/\n/,$books)) {
  s/^[\s\n]+//; s/[\s\n]+$//; 
    #print "booksline=$_<br>";
  if (/(\d+)\s+(\S+)\s+(.+)$/) {
    #print "1=$1,2=$2,3=$3,<br>\n";
    $dict{$2}=$1; $dictshort[$1]=$2; $dict[$1]=$3}}
#print "<br/>readbooks: dict=$#dict<br>\n";
}
#=======================================================================

