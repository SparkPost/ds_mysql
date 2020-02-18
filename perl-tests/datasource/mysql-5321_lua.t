# vim:ts=2:sw=2:et:
use Ecelerity::Test;
use Ecelerity::Test::SMTP;
use Data::Dumper;

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
  plan no_plan;
}

# Write the lua test file
my $lua_script1 = $Conf->{test_base}.'/ds1.lua';
write_lua1($lua_script1);

config
  "datasource mysql" => {
    uri => '("mysql:host=10.79.255.255;dbname=ectest;user=ectest;password=ectest")',
    cache_size => 2,
  },
  "scriptlet mysql_lua" => {
    "script t" => {
      source => "$lua_script1"
    },
  };

start_server;

my $smtp = Ecelerity::Test::SMTP->new();

is $smtp->mail('good@test.messagesystems.com')->code, 250, 'mailfrom accepted';
#diag scalar(localtime());
is $smtp->to('good@foo.com')->code, 550, 'rctpto refused because mysql is not up';
#diag scalar(localtime());
$smtp->rset();
stop_server;

open(LOG, '<', "$Conf->{test_base}/default_paniclog.ec")
  or die "could not open $Conf->{test_base}/default_paniclog.ec";
my @times;
while (<LOG>) {
  chomp;
  push(@times, $1) if (/^(\d{10}):datasource: failed to connect driver mysql/);
}
close LOG;

my $last = shift(@times);
foreach my $ts (@times) {
  is $ts - $last, 10, 'Timeout 10 seconds';
  $last = $ts;
}

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
    local rowB, errB;
    local rcptto = ec_message:rcptto();   -- rcptto extracted from rcptto_str

    query = "select 1 from accounts where name = ?";

    rowA, errA = msys.db.fetch_row("mysql", query, {rcptto},
                                            {raise_error = false});
    rowB, errB = msys.db.fetch_row("mysql", query, {rcptto},
                                            {raise_error = false});

    if (errA != nil) then
      -- It seems that this connection was expected fail
      if string.match(errA, "failed to connect") then
        print ("mysql connection A error: " .. tostring(errA));
      else
        print ("mysql query A error: " .. tostring(errA));
      end
    end

    if (errB != nil) then
      -- It seems that this connection was expected fail
      if string.match(errB, "failed to connect") then
        print ("mysql connection B error: " .. tostring(errB));
      else
        print ("mysql query B error: " .. tostring(errB));
      end
    end

    if (rowA == nil or rowB == nil or rowA["1"] != "1" or rowB["1"] != "1") then
      -- It seems that the lookup failed should have failed because the
      -- connections to mysql failed.
      vctx:set_code(550, "testing1");
    end

    return msys.core.VALIDATE_CONT;
  end

msys.registerModule('dat', mod);
EOT
;
  close $fh;
}
