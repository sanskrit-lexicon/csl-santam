#!"C:\xampp\perl\bin\perl.exe"
#!/usr/bin/perl
#!/vol/perl/bin/perl
# 11.2.2003 SW: Recherche in der tamil-Datenbank 
# 12.8.2008 EJF: modified for sanskrit-lexicon website configuration
# 12.9.2008 EJF: omitted cpd (Concise Pahlavi Dictionary) at request of T. Malten
# 05.31.2015 EJF: Modify to work with sqlite3.
#   Testing was done with XAMPP server under Windows Vista.
print "Content-type: text/html\n\n";
# do 'cgi-include2.pl';
# BEGIN cgi-include2.pl
#!"C:\xampp\perl\bin\perl.exe"
$data1=$ARGV[0] || $ENV{'QUERY_STRING'} || '';
$inq=$ENV{'CONTENT_LENGTH'};
if ($inq) {
  read (STDIN,$data,$inq);
  $data="$data1&$data" if $data1}
else {$data=$data1}
$tr='^?'; $trEsc='\^\?';

$content_type=$ENV{'CONTENT_TYPE'};
$content_type=~/multipart\/form-data\; boundary\=(.+)$/;
#print "=i=content_type==$content_type==<br>\n",
#  "=1=$1==<br>\n";

if ((defined (my $content_type=$ENV{'CONTENT_TYPE'})) &&
  ($content_type=~/multipart\/form-data\; boundary\=(.+)$/)) {
  &zerleg2($data)}
else {&zerleg($data)}
$me=$ENV{'SCRIPT_NAME'};
#print "data=$data.\n";
#$,=","; @F=%F; @n=%n;
#print "data=$data.\nme=$me.\na=@a.\nb=@b.\naorig=@aorig.\n",
#  "borig=@borig.\nn=@n.\nF=@F.\n";
#for (sort keys %F) {print "F{$_}=$F{$_}<br>\n"}

#-----------
sub zerleg {
#-----------
my $data=shift;
my ($a,$b,$n);
$n=0; @a=(); @b=(); @aorig=(); @borig=(); %n=(); %F=();
for (split(/&/,$data)) {
  ($a,$b)=split(/=/,$_);
  $aorig[$n]=$a; $borig[$n]=$b;
  $a=~tr/+/ /;
  $a=~s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $b=~tr/+/ /;
  $b=~s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $b=~s/^[\s\n]+//; $b=~s/[\s\n]+$//;
  eval $weitereErsetzung if $weitereErsetzung;
  $a[$n]=$a; $b[$n]=$b; $n{$a}=$n++;
  if (defined $F{$a}) {$F{$a}.="$tr$b"} else {$F{$a}=$b}}}

#-----------
sub zerleg2 {
#-----------
my $data=shift;
my ($boundary,@list,$part,$a,$b,$n);
$boundary='--'.$1; # RFC1967
@list=split(/$boundary/,$data);
#print "Boundary=$boundary,list=\n",join("\n===",@list);
for $part (@list) {
  ($head,$b)=(split(/\r\n\r\n|\n\n/,$part,2));
  next unless $head;
  next unless $b;
  $b=~s/(\r\n|\n)$//;
  $head=~/name="([^"]*)"/;
  $a=$1;
  #if ($a eq "w") {print "[$part]\n"}
  $head=~/filename="([^"]*)"/;
  $F{"$a.fname"}=$1 if $1;
  #$b=~s/\r?\n$//;
  #print "a=$a, b=$b<br>\n";
  #$b=~s/^[\n\s]+//; $b=~s/[\n\s]+$//;
  #$b=~/\r\s/\s/g; $b=~/\r/\s/g; $b=~s/\s+\n/\n$/g;
  #$b=~s/[\r\s]+$//;
  eval $weitereErsetzung if $weitereErsetzung;
  $a[$n]=$a; $b[$n]=$b; $n{$a}=$n++;
  if (defined $F{$a}) {$F{$a}.="$tr$b"} else {$F{$a}=$b}}}

# END cgi-include2.pl
$dictionary=$F{"dictionary"};
$st=$F{'st'}; $prst=$F{'prst'};
$en=$F{'en'}; $pren=$F{'pren'};
$maxhits=$F{'maxhits'} || 100;
#print "st=$st,prst=$prst,en=$en,pren=$pren<br>\n";
$dir="../dat"; 
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
  #print "check dollar_ = $_<br>";
  my $x = lc($_);
  if ($pr eq "exact") {
    #$where.="($varname $regexp '$wb$_$we')"}
    #$where.="(lower($varname) $regexp '$wb$_$we')"}   # 12-07-2022
    $where.="(lower($varname) $regexp '$wb$x$we')"}   # 12-07-2022
  elsif ($pr eq "prefix") {
    #$where.="(lower($varname) $regexp '$wb$_')"}  #12-07-2022
    $where.="(lower($varname) $regexp '$wb$x')"}  #12-07-2022
  else {
    #$where.="(lower($varname) like '%$_%')"}}} #12-07-2022
    $where.="(lower($varname) like '%$x%')"}}} #12-07-2022

#------------------------
sub fehler {print "<h4>$_[0]</h4>\n</body></html>\n"; exit}
#------------------------
sub opendb { # EJF May 31, 2015. for 
# ignore dbname passed as argument
require DBI;
my  $dbh = DBI->connect ("DBI:SQLite:dbname=../sqlite/tamil.sqlite","","")
             || die "Could not connect to database: "
             . DBI-> errstr;
#print "dbh = $dbh\n";
    return $dbh;

}

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

