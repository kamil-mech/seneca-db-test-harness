#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

WORKDIR=$(bash $PREFIX/../util/conf-obtain.sh app workdir)
USER=$(bash $PREFIX/../util/conf-obtain.sh postgres username)
PASSWORD=$(bash $PREFIX/../util/conf-obtain.sh postgres password)
SCHEMA=$(bash $PREFIX/../util/conf-obtain.sh postgres schema)
echo WORKDIR:$WORKDIR
echo USER:$USER
echo PASSWORD:$PASSWORD
echo SCHEMA:$SCHEMA

# run
IMG="postgres --rm --name postgres-inst -e POSTGRES_USER=$USER -e POSTGRES_USER=$USER -e POSTGRES_PASSWORD=$PASSWORD postgres"
bash $PREFIX/../util/dockrunner.sh "$IMG"

# setup exit trap
STREAMFILE="$PREFIX/../util/temp/"$(ls -a $PREFIX/../util/temp | grep "postgres.stream.out") # TODO this needs to be replaced
trap 'trap - EXIT; echo; echo DONE; echo MONITOR-FIN >> $STREAMFILE; read;' EXIT;

# get container info
DB_HEX=$(cat $PREFIX/../util/temp/$(ls -a $PREFIX/../util/temp | grep "$DB.hex.out"))
DB_HEX=${DB_HEX:0:8}
DB_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $DB_HEX)
DB_PORT=$(bash $PREFIX/util/docker-port.sh $DB_HEX)

export PGHOST=$DB_IP
export PGUSER=$USER
export PGPASSWORD=$PASSWORD

echo SATURATING POSTGRES
echo ---
echo INIT db: $USER, user: $USER, password: $PASSWORD
psql -U $USER -d $USER -f $WORKDIR$SCHEMA
echo USE [CTRL]+[D] to leave
psql -U $USER -d $USER
echo ---

echo
read
echo 