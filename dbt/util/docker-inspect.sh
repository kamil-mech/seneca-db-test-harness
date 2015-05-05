#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX" # <-- WARNING change manually when changing location
source $UTIL/tools.sh

OPTION=$1
HEX=$2

declare -a OPTIONS=("IP" "PORTS" "HEX")
OPLIST="${OPTIONS[@]}" # tostring

if [[ "$OPLIST" == *"$OPTION"* ]]; then
  if [[ "$HEX" != "" ]]; then
    if [[ "$OPTION" == "IP" ]]; then

      IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $HEX)
      if [[ "$IP" == "<no value>" ]]; then error "FAILED TO FETCH IP"
      else echo "$IP"
      fi
    elif [[ "$OPTION" == "PORTS" ]]; then
      call "docker-port.sh $HEX"  # TODO replace all docker-port calls with this script?
    elif [[ "$OPTION" == "HEX" ]]; then
      LABEL="$HEX"
      HEX=""
      I=0
      while [[ true ]]; do
        ((I+=1))

        EEXIST=$(call "file-exist.sh" "$UTIL/temp/$LABEL.hex.out")
        if [[ "$EEXIST" == true ]]; then HEX=$(cat $UTIL/temp/$LABEL.hex.out); fi
        HEX=${HEX:0:8}
        if [[ "$HEX" != "" || "$I" > 3 ]]; then break; fi
        sleep 1
      done
      if [[ "$HEX" == "" ]]; then error "FAILED TO FETCH HEX OF $LABEL"
      else echo "$HEX"
      fi
    fi
  else error "NO HEX/NAME SPECIFIED"
  fi
else error "INVALID OPTION [$OPTION]. CHOOSE ONE: $OPLIST"
fi