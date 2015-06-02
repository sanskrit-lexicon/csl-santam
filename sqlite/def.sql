DROP TABLE tamil;
CREATE TABLE tamil (
 id INT  NOT NULL,
 st VARCHAR(255)  NOT NULL,
 en TEXT NOT NULL
);
.separator "\t"
.import ganz.txt tamil
pragma table_info (tamil);
select count(*) from tamil;
.exit
