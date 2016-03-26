#!/bin/bash

echo "INIT POSTGRESQL"

USERNAME="$1"
PASSWORD="$2"
NAME="$3"
SCHEMA="$4"
IP="$5"
CID="$6"

echo
echo "USERNAME: $USERNAME"
echo "PASSWORD: $PASSWORD"
echo "NAME: $NAME"
echo "SCHEMA: $SCHEMA"
echo "IP: $IP"
echo "CID: $CID"
echo

export PGPASSWORD=password

echo "---"
echo "INIT START"
#export PGPASSWORD=$PASSWORD
#psql -h$IP -U $USERNAME -d $NAME -f $SCHEMA
while read chunk; do
  chunk=$(echo "$chunk" | sed 's/"/\\\'\"'/g')
  docker exec "$CID" bash -c "echo \"$chunk\" >> data.postgresql.sql"  
done < "$SCHEMA"
docker exec "$CID" bash -c "export PGPASSWORD=password && psql -h$IP -U postgres -c \"CREATE DATABASE test\""
docker exec "$CID" bash -c "export PGPASSWORD=password && psql -h$IP -U postgres -d test -c \"CREATE TABLE sys_entity(id VARCHAR (255) NOT NULL, zone VARCHAR (255), base VARCHAR (255), name VARCHAR (255) NOT NULL, fields TEXT, PRIMARY KEY (id))\""
docker exec "$CID" bash -c "export PGPASSWORD=password && psql -h$IP -U postgres -d test -c \"CREATE TABLE test (id VARCHAR (255) NOT NULL, test1 VARCHAR (255), test2 VARCHAR (255), seneca VARCHAR (255), PRIMARY KEY (id))\""
docker exec "$CID" bash -c "export PGPASSWORD=password && psql -h$IP -U postgres -d $NAME -f data.postgresql.sql"
docker exec "$CID" bash -c "export PGPASSWORD=password && psql -h$IP -U postgres -c \"CREATE USER \\\""$USERNAME"\\\" WITH PASSWORD '"$PASSWORD"'\""
docker exec "$CID" bash -c "export PGPASSWORD=password && psql -h$IP -U postgres -c \"ALTER USER \\\""$USERNAME"\\\" WITH SUPERUSER\""
echo "INIT COMPLETE"
echo "---"
#echo "USE [CTRL]+[D] to leave" # used to login
#psql -U $USER -d $USER