# Testing `ds_mysql` module

If you want to test the `ds_mysql` module locally, you must temporarily configure
MySQL/MariaDB with a user, a database, and a single table. You should delete the database and
user after you are done testing.

# Assumptions
  * You have `mysql-server` or `mariadb-server` installed and configured, listening to `localhost`
  * You have the **root** password so you can create new users

> [!NOTE]
> The `ec_runtests.pl` test harness will throw warnings if `msyspg` isn't also installed locally; you can either install and configure `msyspg` or ignore these warnings.

# Setup
Execute the following SQL script to create the necessary resources for the tests to run:

    $ mysql -u root -p < create_ectest.sql

You should test that with (password is also `ectest`):

    mysql -u ectest -p ectest

then in database prompt:

    MariaDB [ectest]> select * from accounts;
    +-------+
    | name  |
    +-------+
    | good  |
    | good1 |
    | good2 |
    | good3 |
    | good4 |
    +-------+
    5 rows in set (0.00 sec)

# Cleanup
After you have successfully run the included tests, you can remove the database and user created
above with:

    mysql -u root -p < drop_ectest.sql
