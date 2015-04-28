#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX" # <-- WARNING change manually when changing location
source $UTIL/tools.sh

DB=$1
TU=$2
TA=$3
ST=$4
IP=$5
PORT=$6
if [[ "$DB" = "postgres" ]]; then DB="postgresql"; fi
DB="$DB-store"

sleep 1


if [[ "$ST" == true ]]; then cd $UTIL/../..; npm run smoke --db=$DB --ip=$IP --port=$PORT # TODO change it so that smoke test can run together with other ones
elif [[ "$TU" = true ]]; then
    npm run utest --db=$DB --ip=$IP --port=$PORT
elif [[ "$TA" = true ]]; then
    npm run atest
else
    npm test --db=$DB --ip=$IP --port=$PORT
fi