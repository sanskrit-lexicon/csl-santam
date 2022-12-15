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
