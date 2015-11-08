#!/bin/bash

echo "RUN POSTGRESQL"

USERNAME="$1"
PASSWORD="$2"
NAME="$3"
SCHEMA="$4"
CIDFILE="$5"

echo
echo "USERNAME: $USERNAME"
echo "PASSWORD: $PASSWORD"
echo "NAME: $NAME"
echo "SCHEMA: $SCHEMA"
echo "CIDFILE: $CIDFILE"
echo

docker run -p 5432:5432 --name postgresql -e POSTGRES_USER=$USERNAME -e POSTGRES_PASSWORD=$PASSWORD --cidfile=$CIDFILE postgres