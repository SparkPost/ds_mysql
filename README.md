# ds_mysql
MySQL-compatible datasource module for Momentum

This is a public domain datasource driver for MySQL-compatible
databases. If you are using Oracle's MySQL, you are responsible for
ensuring that you have the proper license to run this module. It works
equally well with the open-sourced MariaDB.

We include some basic tests that you can verify functionality using
ec_runtests.pl. There are some setup steps you must perform before the
tests can run; see [TESTING.md](TESTING.md) for details. You must build and test this
module on a licensed Momentum MTA instance, but once you build it, you can
copy the module files to other servers and remove the development tools from
the MTA.

#Usage:

Install msys-role-mta and msys-ecelerity-devel metapackages in the directory you
installed Momentum from:

    cd /var/tmp/momentum-?????
    sudo yum install -c momentum.repo --enablerepo=momentum msys-role-mta msys-ecelerity-devel


Install gcc, mysql-devel, mysql-server:

    sudo yum install gcc mysql-devel mysql-server

or on Centos-7:

    sudo yum install gcc mariadb-devel mariadb-server


Clone ds-mysql from github (https://github.com/SparkPost/ds_mysql). You may
need to install git to do this ('sudo yum install git').

Build the ds-mysql code, install, and test:

    cd <ds-mysql checkout directory>
    make
    sudo make install
    make test

NOTE: you have to install the ds_msql driver before you can test, because we
don't support out-of-tree modules.
