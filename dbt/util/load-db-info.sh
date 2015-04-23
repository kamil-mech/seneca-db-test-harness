#!/bin/bash
# requires earlier call to source tools.sh

trap '' ERR # this one is used as source so cannot break code

STREAMFILE=""
I=0
while [[ true ]]; do
  ((I+=1))

  EEXIST=$(call "file-exist.sh" "$UTIL/temp/$STREAMFILE")
  if [[ "$EEXIST" == false || "$STREAMFILE" == "" ]]; then
    # TODO this needs to be replaced
    STREAMFILE=$(ls -a $UTIL/temp | grep "$DB.stream.out")
  fi
  if [[ "$STREAMFILE" != "" || "$I" > 3 ]]; then break; fi
  sleep 1
done

# get container info
IFS="." read -ra LABEL <<< "$STREAMFILE"
LABEL=${LABEL[0]}

if [[ "$LABEL" == "" ]]; then error "FAILED TO IDENTIFY DB" "NOEXIT"; fi

DB_HEX=$(call "docker-inspect.sh" "HEX" "$LABEL")
DB_IP=$(call "docker-inspect.sh" "IP" "$DB_HEX")
DB_PORTS=$(call "docker-inspect.sh" "PORTS" "$DB_HEX")

STREAMFILE="$UTIL/temp/$STREAMFILE"