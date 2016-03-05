#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "INIT CASSANDRA"

NAME="$1"
CID="$2"

echo
echo "NAME: $NAME"
echo "CID: $CID"
echo

echo "---"
echo "INIT START"

data=$(cat $DIR/data.cassandra.cql)

docker exec "$CID" bash -c "echo \"$data\" > data.cassandra.cql"
docker exec "$CID" cqlsh -f "data.cassandra.cql"

echo "INIT COMPLETE"
echo "---"