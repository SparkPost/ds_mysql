/*
 * Copyright (c) 2005-2015 Message Systems, Inc. All rights reserved
 *
 * Message Systems, Inc. has placed this source-code in the public
 * domain. 
 *
 * THIS SOURCE-CODE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOURCE-CODE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef SHARED_MODULE
#define SHARED_MODULE
#endif
#include "ec_config.h"
#include "configuration.h"
#include "module.h"
#include "echash.h"
#include "ecdatasource.h"
#include "hooks/core/reversible_encryption.h"

#include <mysql.h>

static generic_module_infrastructure *my_self = NULL;

struct ec_mysql_driver {
  MYSQL *mysql;
};

struct ec_mysql_stmt {
  MYSQL_RES   *result;
  MYSQL_FIELD *fields;
  MYSQL_ROW   current_data;
};

#define GET_DRV(d)  struct ec_mysql_driver *D = (struct ec_mysql_driver*)d->driver_data;
#define GET_STMT(s)  struct ec_mysql_stmt *S = (struct ec_mysql_stmt*)s->driver_data;


static int ec_mysql_execute(ecdata_stmt *stmt, ecdata_cache_query *cq)
{
  int ret = 0;
  char *query = NULL;
  int query_len;
  int free_query = 0;
  my_ulonglong rowcount;
  GET_STMT(stmt);
  GET_DRV(stmt->driver);

  if (S->result) {
    mysql_free_result(S->result);
    S->result = NULL;
  }

  if (!ec_datasource_parser_execute(stmt, cq, &query, &query_len, &free_query)) {
    goto out;
  }

  if (mysql_real_query(D->mysql, query, query_len) != 0) {
    ec_datasource_error(NULL, stmt, "ds_mysql: execute failed: %d %s\n",
      mysql_errno(D->mysql), mysql_error(D->mysql));
    goto out;
  }

  rowcount = mysql_affected_rows(D->mysql);

  if (rowcount == (my_ulonglong)-1) {
    /* a result-bearing query */

    S->result = mysql_use_result(D->mysql);

    if (S->result == NULL) {
      /* nope, 'twas an error */
      ec_datasource_error(NULL, stmt, "ds_mysql: use_result failed: %d %s\n",
        mysql_errno(D->mysql), mysql_error(D->mysql));

      goto out;
    }

    if (!stmt->executed) {
      /* load up column info now, if we care */

      S->fields = mysql_fetch_fields(S->result);
    }
  }
  ret = 1;

out:
  if (free_query) {
    free(query);
  }

  return ret;
}

static int ec_mysql_describe(ecdata_stmt *stmt)
{
  int i;
  MYSQL_FIELD *mysql_field;
  GET_STMT(stmt);

  mysql_field_seek(S->result, 0);
  ec_datasource_stmt_set_colcount(stmt, mysql_num_fields(S->result));
  for (mysql_field = mysql_fetch_field(S->result), i = 0; mysql_field; mysql_field = mysql_fetch_field(S->result), i++) {
    ec_datasource_stmt_set_colname(stmt, i, mysql_field->name);
  }

  return 1;
}

static int ec_mysql_fetch(ecdata_stmt *stmt)
{
  int i;
  unsigned int ncols;
  unsigned long *current_lengths;
  MYSQL_FIELD *mysql_field;
  
  GET_STMT(stmt);

  if (!S->result) return 0;
  if ((S->current_data = mysql_fetch_row(S->result)) == NULL) {
    return 0;
  }
  current_lengths = mysql_fetch_lengths(S->result);
  ncols = mysql_num_fields(S->result);

  /* populate */
  mysql_field_seek(S->result, 0);
  for (mysql_field = mysql_fetch_field(S->result), i = 0; mysql_field; mysql_field = mysql_fetch_field(S->result), i++) {
    ecdata_value row;
    ec_datasource_init_value(&row);
    if (S->current_data[i]) {
      row.type = ECDATA_TYPE_STR;
      row.len = current_lengths[i];
      row.v.strval = S->current_data[i];
    } else {
      row.type = ECDATA_TYPE_NULL;
      row.len = 0;
      row.v.strval = NULL;
    }
    ec_datasource_add_column_data(stmt, mysql_field->name, &row);
  }
  
  return 1;
}

static int ec_mysql_close(ecdata_stmt *stmt)
{
  GET_STMT(stmt);

  if (S->result) {
    mysql_free_result(S->result);
    S->result = NULL;
  }
  free(S);
  return 1;
}

static void ec_mysql_column_free(ecdata_stmt *stmt, ecdata_value *val)
{
    /* 
      The columnar data that we retrieved will be freed
      when mysql_free_result is called during ec_mysql_close(),
      so this is a no-op.
    */
    return;
}

static struct ec_datasource_statement_class ec_mysql_stmt = {
  ec_mysql_describe,
  ec_mysql_execute,
  ec_mysql_fetch,
  ec_mysql_close,
  ec_mysql_column_free
};

static int ec_mysql_connect(ecdata_driver *drv, ECDict params)
{
  struct ec_mysql_driver *D;
  unsigned int connect_timeout = 10;
  const char *unix_socket = NULL;
  const char *host;
  const char *port;
  const char *dbname;
  const char *user = "";
  const char *pass = "";
  string secure_password;

  if (!dict_key_exists_and_fetch(params, "host", &host))
    host = "localhost";

  if (!dict_key_exists_and_fetch(params, "port", &port))
    port = "3306";

  if (!dict_key_exists_and_fetch(params, "unix", &unix_socket))
    unix_socket = NULL;

  if (!dict_key_exists_and_fetch(params, "dbname", &dbname)) {
    ec_datasource_error(drv, NULL, "ds_mysql: missing dbname during connect\n");
    return 0;
  }

  if (!dict_key_exists_and_fetch(params, "user", &user)) {
    ec_datasource_error(drv, NULL,
      "ds_mysql: missing user name during connect\n");
    return 0;
  }

  if (!dict_key_exists_and_fetch(params, "password", &pass))
    pass = "";

  string_init_type (&secure_password, 128, STRING_TYPE_ECSTRING);
  if (has_core_securecreds_retrieval_hook()) {
    int ret;
    stringwrite (&secure_password, pass, strlen(pass));
    ret =  call_core_securecreds_retrieval_hook ("mysql", (char *)host, (char *)user, &secure_password);
    if (ret == SECURECREDS_MATCH) {
      pass = secure_password.buffer;
    }
    /* else if (ret == SECURECREDS_NO_MATCH) {} leave pass as is */
    else if (ret == SECURECREDS_ERROR) {
      string_destroy(&secure_password);
      return 0;
    }
  }

#ifdef HAVE_MYSQL_THREAD_INIT
  mysql_thread_init();
#endif
  D = calloc(1, sizeof(*D));
  D->mysql = mysql_init(NULL);

  mysql_options(D->mysql, MYSQL_OPT_CONNECT_TIMEOUT, (const void*)&connect_timeout);
#ifdef MYSQL_OPT_USE_REMOTE_CONNECTION
  mysql_options(D->mysql, MYSQL_OPT_USE_REMOTE_CONNECTION, NULL);
#endif

  if (mysql_real_connect(D->mysql, host, user, pass, dbname, atoi(port),
      unix_socket, 0) == NULL) {
    /* borke */
    ec_datasource_error(drv, NULL,
      "ds_mysql: connect failed: %d %s\n",
      mysql_errno(D->mysql), mysql_error(D->mysql));
    mysql_close(D->mysql);
    free(D);
    string_destroy(&secure_password);
    return 0;
  }

  drv->driver_data = D;
  string_destroy(&secure_password);
  return 1;
}

static int ec_mysql_disconnect(ecdata_driver *drv)
{
  GET_DRV(drv);
  mysql_close(D->mysql);
  free(D);
  return 1;
}

static int ec_mysql_prepare(ecdata_driver *drv, ecdata_stmt *stmt, const char *query, const ecdata_column_descriptor *wanted_types)
{
  struct ec_mysql_stmt *S = calloc(1, sizeof(*S));
  stmt->driver_data = S;
  stmt->funcs = &ec_mysql_stmt;
  return ec_datasource_parser_prepare(stmt, 0, query, strlen(query));
}

static int ec_mysql_ping(ecdata_driver *drv)
{
  GET_DRV(drv);
  return mysql_ping(D->mysql) == 0;
}

static int ec_mysql_quote(ecdata_driver *drv, ecdata_value *value, char **quoted, int *quoted_len)
{
  GET_DRV(drv);

  switch (value->type) {
    case ECDATA_TYPE_NULL:
      *quoted = strdup("NULL");
      *quoted_len = strlen(*quoted);
      return 1;

    case ECDATA_TYPE_INT:
      {
        char intbuf[32];
        ec_itoa(value->v.intval, intbuf);
        *quoted = strdup(intbuf);
        *quoted_len = strlen(*quoted);
        return 1;
      }

    case ECDATA_TYPE_STR:
      *quoted = malloc(2 * value->len + 3);
      (*quoted)[0] = '"';
      *quoted_len = mysql_real_escape_string(D->mysql, *quoted + 1, value->v.strval,
          value->len);
      (*quoted)[*quoted_len + 1] = '"';
      (*quoted)[*quoted_len + 2] = '\0';
      *quoted_len += 2;
      return 1;
  }
  return 0;
}

static struct ec_datasource_driver_class ec_mysql_driver = {
  ec_mysql_connect,
  ec_mysql_disconnect,
  ec_mysql_prepare,
  ec_mysql_ping,
  ec_mysql_quote
};

static int ds_mysql_conf_setup(generic_module_infrastructure *self,
                               int ignoreme)
{
  my_self = self;
  return ec_datasource_register_driver("mysql", &ec_mysql_driver, self);
}

static int ds_mysql_ext_init(generic_module_infrastructure *self,
                             ec_config_header *transaction,
                             string *output, int flags)
{
  return 0;
}

EC_MODULE_EXPORT
generic_module_infrastructure ds_mysql = {
{
  EC_MODULE_INIT(EC_MODULE_TYPE_SINGLETON, 0),
  "ds_mysql.c",
  "MySQL datasource module",
  _EC_VER,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  ds_mysql_conf_setup,
  NULL,
  NULL,
  ds_mysql_ext_init,
}};


/* vim:ts=2:sw=2:et:
 * */
