use Ecelerity::Test;
use Ecelerity::Test::Control;
<<DESCRIPTION;

This test modifies a mysql test in the dev test harness in order to test basic CRUD against a local mysql instance
This assumes you're running mysqld.

DESCRIPTION

if (!has_module("ds_mysql")) {
  plan skip_all => "No mysql support on this system";
} else {
  plan tests => 11;
}

use Ecelerity::Test::SMTP;

my $lua_path = $Conf->{test_base} . '/lua.lua';
create_db_test_module($lua_path);

config
  'scriptlet "scriptlet1"' => {
    'script "mysql"' => {
      source => $lua_path
    }
  },
  "datasource mysql" => {
    uri => '("mysql:host=localhost;dbname=ectest;user=ectest;password=ectest")',
    no_cache => 'true'
  };

start_server;

SKIP: {
  my $response = run_command "poke_mysql";
  diag $response;
  unlike ($response,qr/failed to connect/ , 'database is working')
    or skip("connecting to the datasource failed - is mysqld running?", 8);
  if ($response =~ m/mo2042/) {
    run_command("drop_table");
  }
  is (run_command("prep_table"), "success", 'prepped DB')
    or skip ("couldn't prep table", 7);
  is (run_command("insert"), '', 'successfully called msys.db.execute with an "insert" operation');
  is (run_command("retrieve"), 'insert', "insert succeeded");
  is (run_command("update"), '', 'successfully called msys.db.execute with a "update" operation');
  is (run_command("retrieve"), 'update', "update succeeded");
  is (run_command("delete"), '', 'successfully called msys.db.execute with a "delete" operation');
  is (run_command("retrieve"), '', "deletion succeeded");

  is (run_command("drop_table"), 'success', 'successfully dropped table');
}

stop_server;
sub create_db_test_module {
open FH, ">$lua_path"
  or die "couldnt open $lua_path : $@";
print FH <<EOL;
require ("msys.db")
require ("msys.datasource")

local function prep_table()
  st, ab = msys.db.execute("mysql", "create table ectest.mo2042 (name VARCHAR(200))")
  if (st == false) then
    print (tostring(ab))
  else
    print ("success")
  end

end
local function drop_table()
  st, ab = msys.db.execute("mysql", "drop table ectest.mo2042")
  if (st == false) then
    print (tostring(ab))
  else
    print ("success")
  end
end

local function do_delete()
   st, ab = msys.db.execute("mysql", "DELETE FROM ectest.mo2042", {raise_error = false})
   if (st == false) then
     print ("failed")
   else
     print ("") 
   end
end

local function do_insert()
  st, ab = msys.db.execute("mysql", "INSERT INTO ectest.mo2042 VALUES('insert')", {raise_error = false})
  if (st == false) then
    print ("failed")
  else
    print ("") 
  end
end

local function do_update()
  st, ab = msys.db.execute("mysql", "UPDATE ectest.mo2042 SET name='update' where name='insert'", {raise_error = false})
  if (st == false) then
    print ("failed")
  else
    print ("") 
  end
end

local function do_retrieve()
  --return tostring(msys.db.query("mysql", "SELECT name from ectest.mo2042"))
  st, ab = msys.db.query("mysql", "SELECT name from ectest.mo2042", {raise_error = 0})
  if (st == nil) then
    print ("damnit: " .. err)
    return
  end 
  for row in st do
    print (row.name)
  end
end

function poke_mysql()
  st, ab = msys.db.query("mysql", "SHOW TABLES")
  if (st == nil) then
   print ("error: " .. tostring(ab))
  else
    for row in st do
      print (tostring(row))
    end
  end
end

msys.registerControl("insert", do_insert)
msys.registerControl("retrieve", do_retrieve)
msys.registerControl("update", do_update)
msys.registerControl("delete", do_delete)
msys.registerControl("poke_mysql", poke_mysql)
msys.registerControl("drop_table", drop_table)
msys.registerControl("prep_table", prep_table)
EOL

}
