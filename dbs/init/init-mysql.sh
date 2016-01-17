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
mysql -h$IP -u root -ppassword $NAME < $SCHEMA
mysql -h$IP -u root -ppassword -e "GRANT ALL PRIVILEGES on *.* TO '"$USER"'@'%' identified by '"$PASSWORD"' WITH GRANT OPTION; FLUSH PRIVILEGES"
mysql -h$IP -u root -ppassword -e "CREATE DATABASE test"
mysql -h$IP -u root -ppassword -D "test" -e "CREATE TABLE sys_entity (base varchar(255) DEFAULT NULL, name varchar(255) DEFAULT NULL, zone varchar(255) DEFAULT NULL, fields blob, id varchar(255) NOT NULL, seneca blob) ENGINE=InnoDB DEFAULT CHARSET=latin1"
mysql -h$IP -u root -ppassword -D "test" -e "CREATE TABLE test (id varchar (255) NOT NULL, test1 varchar (255), test2 blob, seneca blob) ENGINE=InnoDB DEFAULT CHARSET=latin1"
echo "INIT COMPLETE"
echo "---"
#mysql -u $USER -p$PASSWORD $NAME # used to log in
