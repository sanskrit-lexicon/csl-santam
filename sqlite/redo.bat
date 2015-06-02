echo "remaking input.txt..."
rm tamil.sqlite
echo "remaking sqlite table..."
C:\xampp\MercuryMail\sqlite3.exe  tamil.sqlite < def.sql
