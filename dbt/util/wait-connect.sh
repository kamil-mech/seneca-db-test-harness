#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX" # <-- WARNING change manually when changing location
source $UTIL/tools.sh

declare -i TIMEOUT=$1
declare -i TICKS_PASSED=0
NO_HEAD=$2
IP=$3

IFS=" " read -ra ARGS <<< "$@"   # all to array
PORTS=$(echo ${ARGS[@]})         # all to string
PORTS=${PORTS:${#ARGS[0]}+1}     # remove #1 arg from all string
PORTS=${PORTS:${#ARGS[1]}+1}     # remove #2 arg from all string
PORTS=${PORTS:${#ARGS[2]}+1}     # remove #3 arg from all string

IGNORED_PORTS=("7199" "7000")

if [[ "$NO_HEAD" != true ]]; then
  echo
  echo "CONNECTING TO $IP"
  echo "@ PORTS: ${PORTS[@]}"
fi

while [[ true ]]; do
  WINNER=""
  for PORT in ${PORTS[@]}; do
    if [[ "${IGNORED_PORTS[@]}" == *"$PORT"* ]]; then continue; fi
    trap '' ERR # disable tools.error to keep nc quiet
    CONNECTED=$(nc -z -v -w 1 $IP $PORT 2>&1)
    CONNECTED=$(echo $CONNECTED | grep "succ")
    source $UTIL/tools.sh # reenable tools.error
    if [[ "$CONNECTED" != "" ]]; then WINNER=$PORT; break; fi
  done

  if [[ "$CONNECTED" == "" ]]; then
    printf '.'
    sleep 1
  else
    echo
    echo "SUCCESS @ $WINNER"
    echo
    break
  fi

  if [[ "$TIMEOUT" != "0" ]]; then
    ((TICKS_PASSED+=1))
    if [[ $TICKS_PASSED -ge $TIMEOUT ]]; then
      break
    fi
  fi
done