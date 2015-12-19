#!/bin/bash

echo "INIT POSTGRESQL"
echo "CHECKING FOR psql COMMAND"
psql --version
if [[ "$?" -gt 0 ]]; then
  echo "MISSING COMMAND psql" 1>&2
  echo "INSTALL VIA: sudo apt-get install postgres-xc-client" 1>&2
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

export PGPASSWORD=$PASSWORD

echo "---"
echo "INIT START"
psql -h$IP -U $USERNAME -d $USERNAME -f $SCHEMA
echo "INIT COMPLETE"
echo "---"
#echo "USE [CTRL]+[D] to leave" # used to login
#psql -U $USER -d $USER