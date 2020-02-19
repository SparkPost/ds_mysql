INSTALLED=/opt/msys/ecelerity/libexec/datasource/ds_mysql.so \
  /opt/msys/ecelerity/libexec/datasource/ds_mysql.ecm

all: ds_mysql_so

ds_mysql_so: modules/datasource/ds_mysql.so

modules/datasource/ds_mysql.so:

	/opt/msys/ecelerity/bin/ecxs -c -I/usr/include/mysql \
	ecxs -c -I/usr/include/mysql \
	  -I/opt/msys/ecelerity/include/modules/datasource \
	  -Wl,-Wl,-rpath=/opt/msys/3rdParty/lib64 \
	  -Wl,-Wl,-rpath=/usr/lib64/mysql \
	  -L/usr/lib64/mysql \
	  -lmysqlclient -lpthread -lz -lm -ldl -lssl -lcrypto \
	  modules/datasource/ds_mysql.c

clean:
	rm modules/datasource/ds_mysql.*o 
	
install: ds_mysql_so
	install --compare modules/datasource/ds_mysql.{so,ecm} \
	   /opt/msys/ecelerity/libexec/datasource/

test:
	ec_runtests.pl perl-tests/datasource/mysql*t
	
