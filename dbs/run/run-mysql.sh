#!/bin/bash

echo "RUN MYSQL"

USER="$1"
PASSWORD="$2"
NAME="$3"
SCHEMA="$4"
CIDFILE="$5"

echo
echo "USER: $USER"
echo "PASSWORD: $PASSWORD"
echo "NAME: $NAME"
echo "SCHEMA: $SCHEMA"
echo "CIDFILE: $CIDFILE"
echo

docker run -p 3306:3306 --name mysql -e MYSQL_DATABASE=$NAME -e MYSQL_ROOT_PASSWORD=password --cidfile=$CIDFILE mysql --skip-name-resolve