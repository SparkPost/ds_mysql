# ds_mysql
MySQL-compatible datasource module for Ecelerity

This is a public domain datasource driver for MySQL-compatible
databases. If you are using Oracle's MySQL, you are responsible for
ensuring that you have the proper license to run this code. It works
equally well with the open-sourced MariaDB.

We include some basic tests that you can verify functionality using
ec_runtests.pl. There are some setup steps you must perform before the
tests can run; see TESTING.md for details.

Usage:

Install msys-ecelerity-devel metapackage
Install gcc

make 
make test
sudo make install
