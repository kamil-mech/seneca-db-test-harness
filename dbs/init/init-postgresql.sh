#!/bin/bash

echo "INIT POSTGRESQL"
echo "CHECKING FOR psql COMMAND"
psql --version
if [[ "$?" -gt 0 ]]; then
  echo "MISSING COMMAND psql" 1>&2
  echo "INSTALL VIA: sudo apt-get install postgres-client-9.4" 1>&2
  echo 1>&2
  exit 64
fi

USERNAME="$1"
PASSWORD="$2"
NAME="$3"
SCHEMA="$4"
IP="$5"

echo
echo "USERNAME: $USERNAME"
echo "PASSWORD: $PASSWORD"
echo "NAME: $NAME"
echo "SCHEMA: $SCHEMA"
echo "IP: $IP"
echo

export PGPASSWORD=password

echo "---"
echo "INIT START"
#export PGPASSWORD=$PASSWORD
#psql -h$IP -U $USERNAME -d $NAME -f $SCHEMA
psql -h$IP -U postgres -c "CREATE DATABASE test"
psql -h$IP -U postgres -d test -c "CREATE TABLE sys_entity(id VARCHAR (255) NOT NULL, zone VARCHAR (255), base VARCHAR (255), name VARCHAR (255) NOT NULL, fields TEXT, PRIMARY KEY (id))"
psql -h$IP -U postgres -d test -c "CREATE TABLE test (id VARCHAR (255) NOT NULL, test1 VARCHAR (255), test2 VARCHAR (255), seneca VARCHAR (255), PRIMARY KEY (id))"
psql -h$IP -U postgres -d $NAME -f $SCHEMA
psql -h$IP -U postgres -c "CREATE USER \"$USERNAME\" WITH PASSWORD '"$PASSWORD"'"
psql -h$IP -U postgres -c "ALTER USER \"$USERNAME\" WITH SUPERUSER"
echo "INIT COMPLETE"
echo "---"
#echo "USE [CTRL]+[D] to leave" # used to login
#psql -U $USER -d $USER