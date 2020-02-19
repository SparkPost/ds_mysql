
all:
	ecxs -c -I/usr/include/mysql \
	  -I/opt/msys/ecelerity/include/modules/datasource \
	  -Wl,-Wl,-rpath=/opt/msys/3rdParty/lib64 \
	  -Wl,-Wl,-rpath=/usr/lib64/mysql \
	  -L/usr/lib64/mysql \
	  -lmysqlclient -lpthread -lz -lm -ldl -lssl -lcrypto \
	  modules/datasource/ds_mysql.c
	
install:
	install modules/datasource/ds_mysql.{so,ecm} \
	   /opt/msys/ecelerity/libexec/datasource/

test:
	ec_runtests.pl perl-tests/datasource/mysql*t
	
