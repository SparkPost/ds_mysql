
CC=gcc
CFLAGS=-m64 -gdwarf-3 -D_REENTRANT -DECELERITY -std=gnu99 -Wall -Wmissing-prototypes -fno-omit-frame-pointer -Wformat-security -g3
CPPFLAGS=-I. -Iares -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -D_LARGEFILE64_SOURCE -I/opt/msys/3rdParty/include   -Werror-implicit-function-declaration
SHCFLAGS=-fPIC -m64 -gdwarf-3 -D_REENTRANT -DECELERITY -std=gnu99 -Wall -Wmissing-prototypes -fno-omit-frame-pointer -Wformat-security -g3

CLEAN_TARGETS=clean-ds_mysql_so
TARGETS=ds_mysql_so

# component:ds_mysql
CFLAGS_DS_MYSQL_SO=$(SHCFLAGS) \
	-I/usr/include/mysql \
	-I/opt/msys/3rdParty/include \
	-I/opt/msys/3rdParty/include/x86_64 \
	-DSHARED_MODULE=1 \
	-I/opt/msys/3rdParty/include/modules/datasource \
	-I/opt/msys/3rdParty/include/cidrtree \
	-I/opt/msys/3rdParty/include/misc

# component:ds_mysql
CLEAN_DS_MYSQL_SO=modules/datasource/ds_mysql.so \
	modules/datasource/ds_mysql.lo

# component:ds_mysql
LDFLAGS_DS_MYSQL_SO=-L/opt/msys/3rdParty/lib64 -Wl,-rpath=/opt/msys/3rdParty/lib64 \
	-Wl,-rpath=/usr/lib64/mysql -L/usr/lib64/mysql -lmysqlclient -lpthread -lz -lm -ldl -lssl -lcrypto

# component:ds_mysql
LIBS_DS_MYSQL_SO=-lpcre

# component:ds_mysql
OBJS_DS_MYSQL_SO=modules/datasource/ds_mysql.lo

clean-ds_mysql_so:
	@-rm -f $(CLEAN_DS_MYSQL_SO) 2>/dev/null

ds_mysql_so: modules/datasource/ds_mysql.so

modules/datasource/ds_mysql.so: $(OBJS_DS_MYSQL_SO) $(DEPS_DS_MYSQL_SO)
	@echo "  [ds_mysql_so] linking "$@
	@$(MODULELD) -o $@ $(SHLDFLAGS) $(LDFLAGS_DS_MYSQL_SO) $(OBJS_DS_MYSQL_SO) $(EXTRA_OBJS_DS_MYSQL_SO) $(LIBS_DS_MYSQL_SO) $(LIBS)

modules/datasource/ds_mysql.lo: modules/datasource/ds_mysql.c $(EXTRA_DEPS_DS_MYSQL_SO)
	@echo "  [ds_mysql_so] compiling "$@
	@if $(CC) -MT modules/datasource/ds_mysql.lo -MMD -MP -MF modules/datasource/.deps/ds_mysql.lodep.T  $(CPPFLAGS_DS_MYSQL_SO_OBJ) $(CPPFLAGS_DS_MYSQL_SO) $(CPPFLAGS) $(CFLAGS_DS_MYSQL_SO) $(CFLAGS_DS_MYSQL_SO_OBJ)  -c modules/datasource/ds_mysql.c -o modules/datasource/ds_mysql.lo; then mv -f modules/datasource/.deps/ds_mysql.lodep.T modules/datasource/.deps/ds_mysql.lodep; else rm -f modules/datasource/.deps/ds_mysql.lodep.T; exit 1; fi

include modules/datasource/.deps/ds_mysql.lodep

install: destdirs
#	$(INSTALL)  -m 0755 modules/datasource/ds_mysql.so $(DESTDIR)$(libexecdir)/datasource/
#	$(INSTALL)  -m 0644 modules/datasource/ds_mysql.ecm $(DESTDIR)$(libexecdir)/datasource/
