#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX" # <-- WARNING change manually when changing location
source $UTIL/tools.sh

echo "IMAGE CHECK"
IMG=$1
FD=$2

IMAGES=$(docker images | grep $IMG)
if [[ "$IMAGES" == "" || "$FD" = true ]]; then
    echo "PULLING FROM DOCKER $IMG"
    docker pull $IMG
else echo "$IMG FOUND"
fi