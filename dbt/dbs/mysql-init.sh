#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX/../util" # <-- WARNING change manually when changing location

echo "CHECKING FOR mysql COMMAND"
mysql --version
if [[ "$?" -gt 0 ]]; then
  echo "MISSING COMMAND mysql"
  echo "INSTALL VIA: sudo apt-get install mysql-client-core-5.6"
  echo
  read
  echo 
  exit 0
fi

source $UTIL/tools.sh

WORKDIR=$(call "conf-obtain.sh" "app" "workdir")
USER=$(call "conf-obtain.sh" "mysql" "user")
PASSWORD=$(call "conf-obtain.sh" "mysql" "password")
NAME=$(call "conf-obtain.sh" "mysql" "name")
SCHEMA=$(call "conf-obtain.sh" "mysql" "schema")

echo "WORKDIR:$WORKDIR"
echo "USER:$USER"
echo "PASSWORD:$PASSWORD"
echo "NAME:$NAME"
echo "SCHEMA:$SCHEMA"

# run
IMG="mysql --rm --name mysql-inst -e MYSQL_DATABASE=$NAME -e MYSQL_ROOT_PASSWORD=$PASSWORD mysql --skip-name-resolve"
call "dockrunner.sh" "$IMG"

# loads DB_IP, DB_PORTS, DB_HEX and STREAMFILE vars
source $UTIL/load-db-info.sh

# setup exit trap
trap 'trap - EXIT; echo; echo DONE; echo MONITOR-FIN >> $STREAMFILE; read;' EXIT;

export MYSQL_HOST="$DB_IP"
export MYSQL_TCP_PORT="$DB_PORTS"
export MYSQL_PWD="$PASSWORD"

echo "---"
echo "INIT START"
mysql -u $USER -p$PASSWORD $NAME < $WORKDIR$SCHEMA
echo "INIT COMPLETE"
echo "---"
mysql -u $USER -p$PASSWORD $NAME

echo
read
echo 