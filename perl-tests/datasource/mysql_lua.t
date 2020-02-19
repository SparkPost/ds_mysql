# vim:ts=2:sw=2:et:
use Ecelerity::Test;

# Required schema:
# CREATE TABLE `accounts` (
#  `name` varchar(255) NOT NULL default '',
#    PRIMARY KEY  (`name`)
#    );
# INSERT INTO `accounts` VALUES ('good'),('good1'),('good2'),('good3'),('good4');
#  grant all privileges on ectest.* to ectest identified by 'ectest';

if (!has_module("ds_mysql")) {
  plan skip_all => "No mysql support on this system";
} else {
  plan tests => 9;
}

use Ecelerity::Test::SMTP;

# Write the lua test file
my $lua_script1 = $Conf->{test_base}.'/ds1.lua';
write_lua1($lua_script1);

config
  "datasource mysql" => {
    uri => '("mysql:host=localhost;dbname=ectest;user=ectest;password=ectest")',
    cache_size => 2,
  },
  "scriptlet mysql_lua" => {
    "script t" => {
      source => "$lua_script1"
    },
  };

start_server;

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

# end of test script

# Subroutine to create lua script
sub write_lua1 {
  my $lua_file = shift;
  open my $fh, '>', $lua_file;
  print $fh <<EOT;
require('msys.core');
require('msys.extended.message');
require('msys.datasource');
require('msys.db');

  local mod = {};

  function mod:validate_rcptto(ec_message, rcptto_str, accept_construct, vctx)
    local rowA, errA, query, reason;
    local rowB, errB, params;
    local rcptto = string.match(ec_message:rcptto(), '(.*)\@');

    query = "select 1 from accounts where name = ?";

    rowA, errA = msys.db.fetch_row("mysql", query, {rcptto},
                                            {raise_error = false});
    rowB, errB = msys.db.fetch_row("mysql", query, {rcptto},
                                            {raise_error = false});

    if (errA != nil) then
      print ("mysql query error: " .. tostring(errA));
    end

    if (errB != nil) then
      print ("mysql query error: " .. tostring(errB));
    end

    if (rowA == nil or rowB == nil or rowA["1"] != "1" or rowB["1"] != "1") then
      -- lookup failed
      vctx:set_code(550, "testing1");
    end


    return msys.core.VALIDATE_CONT;
  end

msys.registerModule('dat', mod);
EOT
;
  close $fh;
}
