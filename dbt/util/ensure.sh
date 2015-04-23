#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX" # <-- WARNING change manually when changing location
source $UTIL/tools.sh

ENTITY=$1

# ensure path
IFS="/" read -ra ENTITY <<< "$ENTITY"
LAST_ID=${#ENTITY[@]}-1
RAW=${ENTITY[$LAST_ID]}
ENTITY_PATH=""
for VAR in ${ENTITY[@]}; do
  if [[ "$VAR" == "$RAW" && "$RAW" == *"."* ]]; then

    EEXIST=$(call "file-exist.sh" "$ENTITY_PATH/$RAW")
    if [[ "$EEXIST" = false ]]; then touch "$ENTITY_PATH/$RAW"; fi
    continue
  else
    ENTITY_PATH+="/$VAR"

    EEXIST=$(call "file-exist.sh" "$ENTITY_PATH")
    if [[ "$EEXIST" = false ]]; then mkdir "$ENTITY_PATH"; fi
  fi
done