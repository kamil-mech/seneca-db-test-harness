#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX/../util" # <-- WARNING change manually when changing location
source $UTIL/tools.sh

WORKDIR=$(call "conf-obtain.sh" "app" "workdir")
USER=$(call "conf-obtain.sh" "postgres" 'username')
PASSWORD=$(call "conf-obtain.sh" "postgres" "password")
SCHEMA=$(call "conf-obtain.sh" "postgres" "schema")

echo "WORKDIR:$WORKDIR"
echo "USER:$USER"
echo "PASSWORD:$PASSWORD"
echo "SCHEMA:$SCHEMA"

# run
IMG="postgres --rm --name postgres-inst -e POSTGRES_USER=$USER -e POSTGRES_USER=$USER -e POSTGRES_PASSWORD=$PASSWORD postgres"
call "dockrunner.sh" "$IMG"

# loads DB_IP, DB_PORTS, DB_HEX and STREAMFILE vars
source $UTIL/load-db-info.sh

# setup exit trap
trap 'trap - EXIT; echo; echo DONE; echo MONITOR-FIN >> $STREAMFILE; read;' EXIT;

export PGHOST="$DB_IP"
export PGUSER="$USER"
export PGPASSWORD="$PASSWORD"

echo "SATURATING POSTGRES"
echo "---"
echo "INIT db: $USER, user: $USER, password: $PASSWORD"
psql -U $USER -d $USER -f $WORKDIR$SCHEMA
echo "USE [CTRL]+[D] to leave"
psql -U $USER -d $USER
echo "---"

echo
read
echo 