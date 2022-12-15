<?php
 $dbg = false;
 //if ($dbg) {echo "$_SERVER<br>\n";}
 // Request parameters:
 sanitize_REQUEST_all();
 $dictionary=$_REQUEST['dictionary'];
 $st=$_REQUEST['st'];
 $prst=$_REQUEST['prst'];
 $en=$_REQUEST['en'];
 $pren=$_REQUEST['pren'];
 $maxhits=$_REQUEST['maxhits'] ;
 $parmkeys = array_keys($_REQUEST);
 //$_SERVER['SCRIPT_NAME']='HELLO';
 if ($dbg) {
  foreach($parmkeys as $key) {
   $val = $_REQUEST[$key];
   echo "$key = $val,  "; 
  }
  echo "<br>\n";
 }
// $dictbooks is a simple array. each element an array of 3 strings:
// book number, shortname, fullname.  How to deal with ALL ?
$dictbooks = readbooks();  // simple array.
// get dictname and dictnum from $dictionary
list($dictnum,$dictname) = dictionary_info($dictionary,$dictbooks);
if ($dbg) {
 echo "dictnum=$dictnum, dictname=$dictname<br>\n";
}
$st = trim($st);
$en = trim($en);
if (! ( (strlen($st)>1) || (strlen($en) > 1)) ) {
 fehler("No search has been formulated.");
}
echo "<html><head><title>$dictname: Search Results</title></head>\n",
  "<body bgcolor=\"#ffffff\">\n<h1>$dictname: Search Results</h1>\n";
$where = compute_where($dictnum,$st,$prst,$en,$pren);
if ($dbg) {
 echo "<br>where: $where<br>\n";
}
// select statement for sql
$befehl="select id,st,en from tamil where $where order by st collate nocase";
// put in LIMIT

$befehl .= " LIMIT $maxhits";
if ($dbg) {
 echo "befehl: $befehl<br>\n";
}
// get results
$results = selectfromdb($befehl);
$nresults = count($results);
if ($dbg) {
 echo "select $nresults results found<br>\n";
}
if ($dictnum == '0') { // user chose ALL dictionaries. Print abbreviations
  echo "<table>\n";
  foreach($dictbooks as $dictbook) {
   list($bnum,$bshort,$blong) = $dictbook;
   // exclude Pahlavi Dictionary, since html does not mention.
   if ($bnum != '4') {
    echo "<tr><td>($bshort) </td><td>=</td><td> $blong</td></tr>\n";
   }
  }
  echo "</table><br>\n";
}
echo "<table cellspacing=3>";
for($i=0;$i<$nresults;$i++) {
 $result = $results[$i];
 $hitnr = $i + 1;
 list($id,$st,$en) = $result;  // NOTE reused variables
 if ($dictnum == '0') {
  $idx = intval($id) - 1;
  list($bnum,$bshort,$blong) = $dictbooks[$idx];
  $buchaus = "<td valign='top'>($bshort)</td>";
 } else {
  $buchaus = "";
 }
 //
 echo "<tr><td align=right valign=top>$hitnr</td>\n";
 echo "$buchaus";
 echo "<td valign=top> <b>$st</b></td>\n";
 // otherwise, get unprintable characters.
 // Note: better would be to use 'iconv' on ganz.txt, then remake tamil.sqlite.
 // Perl code seems to do this conversion on its own.
 $en1 = iconv("Windows-1252","UTF-8",$en); 
 echo "<td valign=top>$en1</td></tr>\n";
}
echo "</table>\n";
if ($nresults == 0) {
 echo "No entries found.<br>";
}
echo "</body></html>";

/************************************************************
functions
*/
function fehler($msg) {
 $ans = "<h4>$msg</h4>\n</body></html>\n";
 echo $ans;
 exit;
}
function readbooks() {
 $filename = '../dat/books'; // a text file
 if (! file_exists($filename)) {
  fehler("missing file $filename");
 }
 $lines = file($filename,FILE_IGNORE_NEW_LINES);
 $dbg = false;
 $ans = array();
 foreach($lines as $line) {
  if ($dbg) {echo "$filename: $line<br>";}
  if (! preg_match('/^([1-4]) (.*?) (.*)$/',$line,$matches)) {
   fehler("readbooks error: $line");
  }
  // book number, shortname, fullname
  $ans1 = array($matches[1],$matches[2],$matches[3]);
  $ans[] = $ans1;
 }
 return $ans;
}
function dictionary_info($dictionary,$dictbooks) {
 if ($dictionary == 'all') {
  $dictnum = '0';
  $dictname = 'All dictionaries';
 } else {
  $found = false;
  for($i=0; $i < count($dictbooks); $i++) {
   $dictbook = $dictbooks[$i];
   list($dictnumstr,$dictshort,$dictlong) = $dictbook;
   if ($dictionary == $dictshort) {
    $dictnum = $dictnumstr;
    $dictname = $dictlong;
    $found = true;
    break;
   }
  }
  if (! $found) {
   fehler("No dictonary has been selected.$dictionary");  // exits
  }
 }
 return array($dictnum,$dictname);
}
function compute_where($dictnum,$st,$prst,$en,$pren) {
 // construct the 'where' string for sql search
 // sqlite file has 3 fields id (= dictnum), st (headword), en (text)
 // ---- id dictnum
 // assume $dictnum is a string
 $dbg = false;
 if ($dictnum == '0') {
  // 'all', exclude the 4th (Pali dictionary)
  $where = "id<4";
 } else {
  $where = "id=$dictnum";
 }
 // ---- st
 if ($st != "") {
  $temp = where1($st,'st',$prst);
  $where .= " and $temp";
 }
 if ($en != "") {
  $temp = where1($en,'en',$pren);
  $where .= " and $temp";
 }
 return $where;
}
function where1($var,$varname,$pr) {
 $wb = "\\b"; // word begin in regexp
 $we = "\\b"; // word end
 // allow $var to have multiple words, separated by one or more spaces
 $var = trim($var);
 $parts = preg_split('/ +/',$var);
 $ans = "";
 // all regexp matches are case-insensitive
 $regexp = 'regexp';  // the regexp function in sqlite
 // in sqlite select, lowdata puts the result text into lower case for regexp
 $lowdata = "lower($varname)";  //lower is sqlite function name
 for($ipart=0;$ipart < count($parts); $ipart++) {
  $part = $parts[$ipart];
  $x = strtolower($part);  // 
  if ($pr == "exact") {
    $ans1 ="($lowdata $regexp '$wb$x$we')";
  } else if ($pr == "prefix") {
    $ans1 ="($lowdata $regexp '$wb$x')";
  } else {
    $ans1 ="($lowdata like '%$x%')";
  }
  if ($ipart != 0) {
   $ans .= " and $ans1";
  }else {
   $ans .= $ans1;
  }
  // echo "where1 dbg: ipart=$ipart, part=$part, ans1=$ans1, ans=$ans<br>\n";
 }
 return $ans;
}
function sanitize_REQUEST_all() { 
 $parmkeys = array_keys($_REQUEST);
 foreach($parmkeys as $key) {
  $old = $_REQUEST[$key];
  // remove all HTML tags from a string
  // another could be FILTER_SANITIZE_URL
  $new = filter_var($old,FILTER_SANITIZE_STRING);
  $_REQUEST[$key] = $new;
 }
}
function selectfromdb($sql) {
 $sqlitefile = "../sqlite/tamil.sqlite";
 try {
   $file_db = new PDO('sqlite:' .$sqlitefile);
   $file_db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
   $status=true;
  } catch (PDOException $e) {
   $file_db = null;
   fehler("Cannot open " . $sqlitefile . "\n");
  }
 $file_db->sqliteCreateFunction('regexp', '_sqliteRegexp', 2);
 //echo "sql=$sql<br>\n";
 try {
  $result = $file_db->query($sql);
 } catch (PDOException $e)  {
  fehler("selectfromdb error: $e");
 }
 $ansarr = array();
 foreach($result as $m) {
  $rec = array($m['id'],$m['st'],$m['en']);
  $ansarr[] = $rec;
 }
 // close db
 $file_db = null;
 return $ansarr;
}
//$nreg=0;
function _sqliteRegexp($pattern, $string) {
 /*
  GLOBAL $nreg;
  $nreg = $nreg + 1;
  if ($nreg < 10) {echo "_sqliteRegexp $nreg $string<br>\n";}
 */
    #if(preg_match('/^'.$pattern.'$/i', $string)) {
    if(preg_match('/'.$pattern.'/i', $string)) {
        return true;
    }
    return false;
}

?>
