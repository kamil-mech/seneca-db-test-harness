#!/bin/bash
trap 'kill $$' SIGINT
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

STREAMFILE=$1
IP=$2

IFS=" " read -ra ARGS <<< "$@"   # from args to array
PORTS=$(echo ${ARGS[@]})         # back to string
PORTS=${PORTS:${#ARGS[0]}+1}     # remove #1 arg
PORTS=${PORTS:${#ARGS[1]}+1}     # remove #2 arg

ID=$[ 1 + $[ RANDOM % 10000 ]]

FILEPATH="$PREFIX/temp/[$ID]connected.out"
> $FILEPATH

# detect errors
PEEK=$(bash $PREFIX/peek.sh $STREAMFILE >/dev/null true)

# if no errors
# wait for image to be up & listening
NO_HEAD=false
CONNECTED=""
while [[ "$PEEK" != "ERR" && "$PEEK" != "FIN" && "$PORTS" != "" && "$CONNECTED" != *"SUCCESS"* ]]; do
  bash $PREFIX/wait-connect.sh 2 $NO_HEAD $IP $PORTS | tee $FILEPATH
  PEEK=$(bash $PREFIX/peek.sh $STREAMFILE >/dev/null true)
  CONNECTED=$(cat $FILEPATH)
  NO_HEAD=true
done