CREATE DATABASE ectest;
CREATE USER ectest IDENTIFIED BY 'ectest';
GRANT ALL ON ectest.* TO ectest;
USE ectest;
CREATE TABLE `accounts` (`name` varchar(255) NOT NULL default '' PRIMARY KEY);
INSERT INTO `accounts` VALUES ('good'),('good1'),('good2'),('good3'),('good4');
