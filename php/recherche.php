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
 // Case-sensitive toggle (Wave 2): opt-out from the default case-folded search so HK's
 // phonemic letter case (A=ā, T=ṭ, S=ṣ vs s, ...) isn't conflated for power users. Unset
 // when the form checkbox isn't ticked (browsers omit unchecked checkboxes entirely).
 $case_sensitive = isset($_REQUEST['case_sensitive']) && $_REQUEST['case_sensitive'] == '1';
 $maxhits=$_REQUEST['maxhits'] ;
 // Default + clamp: a missing/empty/0/negative value would otherwise produce
 // "LIMIT 0" (or a SQLite error for negative); a huge value would defeat the
 // form's own cap. Mirror the form's own default (50) and max (1000).
 $maxhits = (int)$maxhits;
 if ($maxhits <= 0) {
  $maxhits = 50;
 } else if ($maxhits > 1000) {
  $maxhits = 1000;
 }
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
$where = compute_where($dictnum,$st,$prst,$en,$pren,$case_sensitive);
if ($dbg) {
 echo "<br>where: $where<br>\n";
}
// select statement for sql
$befehl="select id,st,en from tamil where $where order by st collate nocase";
// put in LIMIT

$befehl .= " LIMIT " . (int)$maxhits;  // SQLi guard: $maxhits is $_REQUEST input, already defaulted/clamped above
if ($dbg) {
 echo "befehl: $befehl<br>\n";
}
// get results
$results = selectfromdb($befehl,$case_sensitive);
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
 // Escape: $msg may embed user input (e.g. the unknown dictionary code),
 // which would otherwise be reflected XSS. All fehler messages are plain text.
 $ans = "<h4>" . htmlspecialchars($msg, ENT_QUOTES) . "</h4>\n</body></html>\n";
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
function compute_where($dictnum,$st,$prst,$en,$pren,$case_sensitive=false) {
 // construct the 'where' string for sql search
 // sqlite file has 3 fields id (= dictnum), st (headword), en (text)
 // ---- id dictnum
 // assume $dictnum is a string
 $dbg = false;
 if ($dictnum == '0') {
  // 'all', exclude the 4th (Pahlavi dictionary)
  $where = "id<4";
 } else {
  $where = "id=$dictnum";
 }
 // ---- st
 if ($st != "") {
  $temp = where1($st,'st',$prst,$case_sensitive);
  $where .= " and $temp";
 }
 if ($en != "") {
  $temp = where1($en,'en',$pren,$case_sensitive);
  $where .= " and $temp";
 }
 return $where;
}
function where1($var,$varname,$pr,$case_sensitive=false) {
 $wb = "\\b"; // word begin in regexp
 $we = "\\b"; // word end
 // allow $var to have multiple words, separated by one or more spaces
 $var = trim($var);
 $parts = preg_split('/ +/',$var);
 $ans = "";
 // Case-sensitive mode (Wave 2) skips the lower()/strtolower() folding below. Two things
 // beyond that are needed for it to actually take effect (both handled here / in
 // selectfromdb()): SQLite's REGEXP infix operator is hardwired to a function literally
 // named 'regexp', so a case-sensitive variant must be called via ordinary function-call
 // syntax (regexp_cs(pattern, col)), not as an infix operator -- verified empirically,
 // "col regexp_cs 'pattern'" is a SQL syntax error. And SQLite's LIKE is
 // case-INsensitive for ASCII by default regardless of lower()-folding in the query, so
 // selectfromdb() sets PRAGMA case_sensitive_like when $case_sensitive is true.
 // in sqlite select, lowdata puts the result text into lower case for regexp (unless case-sensitive)
 $lowdata = $case_sensitive ? $varname : "lower($varname)";  //lower is sqlite function name
 for($ipart=0;$ipart < count($parts); $ipart++) {
  $part = $parts[$ipart];
  $part_term = $case_sensitive ? $part : strtolower($part);
  // LIKE-branch escaping: neutralize the LIKE metacharacters '%' and '_' (and
  // '\' itself, the escape char) so a literal '%'/'_' in the query matches
  // itself instead of acting as a wildcard -- see the ESCAPE clause below.
  // Then escape ' for the SQLite string literal (SQLi guard).
  $x = str_replace(array('\\', '%', '_'), array('\\\\', '\\%', '\\_'), $part_term);
  $x = str_replace("'", "''", $x);
  // The regexp branches feed the value into _sqliteRegexp()/_sqliteRegexpCS() -> preg_match()
  // as a PCRE pattern, so the term must ALSO be preg_quote()d -- otherwise regex
  // metacharacters inject and a term like "(a+)+" is a catastrophic-backtracking ReDoS
  // (run per row). $wb/$we are the intended \b word-boundary anchors and are left active.
  $xr = str_replace("'", "''", preg_quote($part_term, '/'));
  if ($pr == "exact") {
    $pattern = "$wb$xr$we";
  } else if ($pr == "prefix") {
    $pattern = "$wb$xr";
  } else if ($pr == "suffix") {
    $pattern = "$xr$we";
  } else {
    $pattern = null; // substring: LIKE, not regexp
  }
  if ($pattern !== null) {
    $ans1 = $case_sensitive
      ? "(regexp_cs('$pattern', $lowdata))"
      : "($lowdata regexp '$pattern')";
  } else { // substring
    $ans1 ="($lowdata like '%$x%' ESCAPE '\\')";
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
  //$new = filter_var($old,FILTER_SANITIZE_STRING); //deprecated php 8.2
  // $new = filter_var($old,FILTER_SANITIZE_URL); // dog cat not found
  $new = filter_var($old,FILTER_UNSAFE_RAW);
  $_REQUEST[$key] = $new;
 }
}
function selectfromdb($sql,$case_sensitive=false) {
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
 $file_db->sqliteCreateFunction('regexp_cs', '_sqliteRegexpCS', 2);
 if ($case_sensitive) {
  // SQLite's LIKE is case-insensitive for ASCII by default, independent of any
  // lower()/strtolower() folding done in the query itself -- this pragma is what
  // actually makes the 'substring' (LIKE) match mode case-sensitive. Connection-local,
  // so it never affects any other request.
  $file_db->exec('PRAGMA case_sensitive_like = ON;');
 }
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
function _sqliteRegexpCS($pattern, $string) {
    // Case-sensitive counterpart of _sqliteRegexp() -- same pattern, no /i flag.
    if(preg_match('/'.$pattern.'/', $string)) {
        return true;
    }
    return false;
}

?>
