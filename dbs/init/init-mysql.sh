#!/bin/bash

echo "INIT MYSQL"
echo "CHECKING FOR mysql COMMAND"
mysql --version
if [[ "$?" -gt 0 ]]; then
  echo "MISSING COMMAND mysql" 1>&2
  echo "INSTALL VIA: sudo apt-get install mysql-client-core-5.6"  1>&2
  echo  1>&2
  exit 64
fi

USER="$1"
PASSWORD="$2"
NAME="$3"
SCHEMA="$4"
IP="$5"

echo
echo "USER: $USER"
echo "PASSWORD: $PASSWORD"
echo "NAME: $NAME"
echo "SCHEMA: $SCHEMA"
echo "IP: $IP"
echo

echo "---"
echo "INIT START"
mysql -h$IP -u $USER -p$PASSWORD $NAME < $SCHEMA
echo "INIT COMPLETE"
echo "---"
#mysql -u $USER -p$PASSWORD $NAME # used to log in