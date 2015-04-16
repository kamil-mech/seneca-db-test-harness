#!/bin/bash
trap 'kill $$' SIGINT
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

WORKDIR=$(bash $PREFIX/conf-obtain.sh app workdir)

DB=$1
TU=$2
TA=$3
IP=$4
PORT=$5
if [[ "$DB" = "postgres" ]]; then DB="postgresql"; fi
DB="$DB-store"

sleep 1

cd $WORKDIR
if [[ "$TU" = true ]]; then
    npm run utest --db=$DB --ip=$IP --port=$PORT
elif [[ "$TA" = true ]]; then
    npm run atest
else
    npm test --db=$DB --ip=$IP --port=$PORT
fi