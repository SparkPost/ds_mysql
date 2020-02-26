create database ectest;
grant all on ectest.* to ectest identified by 'ectest';
use ectest;
CREATE TABLE `accounts` (`name` varchar(255) NOT NULL default '', PRIMARY KEY  
INSERT INTO `accounts` VALUES ('good'),('good1'),('good2'),('good3'),('good4');
