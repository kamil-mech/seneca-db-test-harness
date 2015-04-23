#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX" # <-- WARNING change manually when changing location
source $UTIL/tools.sh

echo "KILLING CONTAINERS"
CONTAINERS=$(docker ps -a -q)
if [[ "$CONTAINERS" == "" ]]; then echo "NOTHING TO KILL"
else
    docker kill $(docker ps -a -q)

    CONTAINERS=$(docker ps -a -q)
    if [[ "$CONTAINERS" != "" ]];  then docker rm $(docker ps -a -q); fi
fi