#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

WORKDIR=$(bash $PREFIX/../util/conf-obtain.sh app workdir)
USER=$(bash $PREFIX/../util/conf-obtain.sh mysql user)
PASSWORD=$(bash $PREFIX/../util/conf-obtain.sh mysql password)
NAME=$(bash $PREFIX/../util/conf-obtain.sh mysql name)
SCHEMA=$(bash $PREFIX/../util/conf-obtain.sh mysql schema)
echo WORKDIR:$WORKDIR
echo USER:$USER
echo PASSWORD:$PASSWORD
echo NAME:$NAME
echo SCHEMA:$SCHEMA

# run
IMG="mysql --rm --name mysql-inst -e MYSQL_DATABASE=$NAME -e MYSQL_ROOT_PASSWORD=$PASSWORD mysql --skip-name-resolve"
bash $PREFIX/../util/dockrunner.sh "$IMG"

# setup exit trap
STREAMFILE="$PREFIX/../util/temp/"$(ls -a $PREFIX/../util/temp | grep "mysql.stream.out") # TODO this needs to be replaced
trap 'trap - EXIT; echo; echo DONE; echo MONITOR-FIN >> $STREAMFILE; read;' EXIT;

# get container info
DB_HEX=$(cat $PREFIX/../util/temp/$(ls -a $PREFIX/../util/temp | grep "$DB.hex.out"))
DB_HEX=${DB_HEX:0:8}
DB_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $DB_HEX)
DB_PORTS=$(bash $PREFIX/../util/docker-port.sh $DB_HEX)

export MYSQL_HOST=$DB_IP
export MYSQL_TCP_PORT=$DB_PORTS
export MYSQL_PWD=$PASSWORD

echo ---
echo INIT START
mysql -u $USER -p$PASSWORD $NAME < $WORKDIR$SCHEMA
echo INIT COMPLETE
echo ---
mysql -u $USER -p$PASSWORD $NAME

echo
read
echo 