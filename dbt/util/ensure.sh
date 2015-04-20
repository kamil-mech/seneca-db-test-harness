#!/bin/bash
trap 'kill $$' SIGINT
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ENTITY=$1

# ensure path
IFS="/" read -ra ENTITY <<< "$ENTITY"
LAST_ID=${#ENTITY[@]}-1
RAW=${ENTITY[$LAST_ID]}
ENTITY_PATH=""
for VAR in ${ENTITY[@]}; do
  if [[ "$VAR" == "$RAW" && "$RAW" == *"."* ]]; then

    EEXIST=$(bash $PREFIX/file-exist.sh $ENTITY_PATH/$RAW)
    if [[ "$EEXIST" = false ]]; then touch "$ENTITY_PATH/$RAW"; fi
    continue
  else
    ENTITY_PATH+="/$VAR"

    EEXIST=$(bash $PREFIX/file-exist.sh $ENTITY_PATH)
    if [[ "$EEXIST" = false ]]; then mkdir "$ENTITY_PATH"; fi
  fi
done