# vim:ts=2:sw=2:et:
use Ecelerity::Test;
use IO::File;
use strict;

my $credmgr = '../scripts/credmgr';
my $random_generator = '/dev/urandom';
my $db_file = "$Conf->{test_base}/credentials.db";
my $key_file = "$Conf->{test_base}/credentials.key";
my $host = 'sinkhole.int.messagesystems.com';
my $facility = 'mysql';
my $user = 'ectest';
my $password = 'ectest';
my $log = "$Conf->{test_base}/create_db.log";
my $script_ret = system("$credmgr create_db -d $db_file >$log 2>&1");

if ($ENV{ECELERITY_USE_MULTI_EVENT_LOOPS}) {
  plan skip_all => "sieve is not supported with multiple event loops";
} elsif (!has_module("ds_mysql")) {
  plan skip_all => "No mysql support on this system";
} else {
  plan tests => 16;
}

ok (-s $db_file, "create securecreds db");

$log = "$Conf->{test_base}/create_key.log";
$script_ret = system("$credmgr create_key -d $db_file -k $key_file -r $random_generator >$log 2>&1");
ok (-s $key_file, "create securecreds key file");

$log = "$Conf->{test_base}/create_credentials.log";

$script_ret = system("$credmgr set_cred -d $db_file -k $key_file -r $random_generator -h localhost -u ecuser -f pgsql -p ecuser >>$log 2>&1");
ok ($script_ret == 0, "insert pgsql required credentials");
$script_ret = system("$credmgr set_cred -d $db_file -k $key_file -r $random_generator -h $host -f $facility -u $user -p $password >>$log 2>&1");
ok ($script_ret == 0, "insert $facility target credentials");

# Required schema:
# CREATE TABLE `accounts` (
#  `name` varchar(255) NOT NULL default '',
#    PRIMARY KEY  (`name`)
#    );
# INSERT INTO `accounts` VALUES ('good'),('good1'),('good2'),('good3'),('good4');
#  grant all privileges on ectest.* to ectest identified by 'ectest';


use Ecelerity::Test::SMTP;

needs 'sieve';
needs 'sievelib';
config
  "securecreds" => {
    credentials => "$db_file",
    key => "$key_file", 
    debug_level => 'debug',
  },
  "datasource mysql" => {
    uri => '("mysql:host=sinkhole.int.messagesystems.com;dbname=ectest;user=ectest")',
    cache_size => 2,
  };

start_server;

set_sieve code => write_sieve1(), phase => 'rcptto_phase1';
my $smtp = Ecelerity::Test::SMTP->new();

is $smtp->mail('good@test.messagesystems.com')->code, 250;
is $smtp->to('good@foo.com')->code, 250;
is $smtp->to('good1@foo.com')->code, 250;
is $smtp->to('good2@foo.com')->code, 250;
is $smtp->to('good3@bar.com')->code, 250;
is $smtp->to('good4@bar.com')->code, 250;
is $smtp->to('bad@bar.com')->code, 550;
$smtp->rset();
stop_server;

sub write_sieve1 {
return q/

($ok) = ds_fetch "mysql" "select 1 from accounts where name = ?" 
          ["%{vctx_mess:rcptto_localpart}"];
($ok2) = ds_fetch "mysql" "select 1 from accounts where name = ?" 
          ["%{vctx_mess:rcptto_localpart}"];
if not allof(ec_test :is "${ok}" "1", ec_test :is "${ok2}" "1") {
  ec_action 550 "testing1";
}
/;
}

