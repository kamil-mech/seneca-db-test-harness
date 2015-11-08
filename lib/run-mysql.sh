#!/bin/bash

echo "CHECKING FOR mysql COMMAND"
mysql --version
if [[ "$?" -gt 0 ]]; then
  echo "MISSING COMMAND mysql" 1>&2
  echo "INSTALL VIA: sudo apt-get install mysql-client-core-5.6"  1>&2
  echo  1>&2
  exit 64
fi

SCHEMA="$1"
USER="$2"
PASSWORD="$3"
NAME="$4"
CIDFILE="$5"

echo
echo "SCHEMA: $SCHEMA"
echo "USER: $USER"
echo "PASSWORD: $PASSWORD"
echo "NAME: $NAME"
echo "CIDFILE: $CIDFILE"
echo

docker run -p 3306:3306 --name mysql -e MYSQL_DATABASE=$NAME -e MYSQL_ROOT_PASSWORD=$PASSWORD --cidfile=$CIDFILE mysql --skip-name-resolve