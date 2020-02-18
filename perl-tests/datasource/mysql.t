# vim:ts=2:sw=2:et:
use Ecelerity::Test;

# Required schema:
# CREATE TABLE `accounts` (
#  `name` varchar(255) NOT NULL default '',
#    PRIMARY KEY  (`name`)
#    );
# INSERT INTO `accounts` VALUES ('good'),('good1'),('good2'),('good3'),('good4');
#  grant all privileges on ectest.* to ectest identified by 'ectest';

if ($ENV{ECELERITY_USE_MULTI_EVENT_LOOPS}) {
  plan skip_all => "sieve is not supported with multiple event loops";
} elsif (!has_module("ds_mysql")) {
  plan skip_all => "No mysql support on this system";
} else {
  plan tests => 12;
}

use Ecelerity::Test::SMTP;

needs 'sieve';
needs 'sievelib';
config
  "datasource mysql" => {
    uri => '("mysql:host=sinkhole.int.messagesystems.com;dbname=ectest;user=ectest;password=ectest")',
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

