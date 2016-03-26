#!/bin/bash

echo "INIT MYSQL"

USER="$1"
PASSWORD="$2"
NAME="$3"
SCHEMA="$4"
IP="$5"
CID="$6"

echo
echo "USER: $USER"
echo "PASSWORD: $PASSWORD"
echo "NAME: $NAME"
echo "SCHEMA: $SCHEMA"
echo "IP: $IP"
echo "CID: $CID"
echo

echo "---"
echo "INIT START"
while read chunk; do
  chunk=$(echo "$chunk" | sed 's/`/\\\'\`'/g')
  docker exec "$CID" bash -c "echo \"$chunk\" >> data.mysql.sql"  
done < "$SCHEMA"
docker exec "$CID" bash -c "mysql -h$IP -u root -ppassword $NAME < data.mysql.sql"
docker exec "$CID" mysql -h"$IP" -u root -ppassword "$NAME" -e "GRANT ALL PRIVILEGES on *.* TO '"$USER"'@'%' identified by '"$PASSWORD"' WITH GRANT OPTION; FLUSH PRIVILEGES"
docker exec "$CID" mysql -h"$IP" -u root -ppassword "$NAME" -e "CREATE DATABASE test"
docker exec "$CID" mysql -h"$IP" -u root -ppassword -D "test" -e "CREATE TABLE sys_entity (base varchar(255) DEFAULT NULL, name varchar(255) DEFAULT NULL, zone varchar(255) DEFAULT NULL, fields blob, id varchar(255) NOT NULL, seneca blob) ENGINE=InnoDB DEFAULT CHARSET=latin1"
docker exec "$CID" mysql -h"$IP" -u root -ppassword -D "test" -e "CREATE TABLE test (id varchar (255) NOT NULL, test1 varchar (255), test2 blob, seneca blob) ENGINE=InnoDB DEFAULT CHARSET=latin1"
echo "INIT COMPLETE"
echo "---"
#mysql -u $USER -p$PASSWORD $NAME # used to log in
