#!/bin/bash
trap 'kill $$' SIGINT

declare -i TIMEOUT=$1
declare -i TICKS_PASSED=0
NO_HEAD=$2
IP=$3

IFS=" " read -ra ARGS <<< "$@"   # from args to array
PORTS=$(echo ${ARGS[@]})         # back to string
PORTS=${PORTS:${#ARGS[0]}+1}     # remove #1 arg
PORTS=${PORTS:${#ARGS[1]}+1}     # remove #2 arg
PORTS=${PORTS:${#ARGS[2]}+1}     # remove #3 arg

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
    CONNECTED=$(nc -z -v -w 1 $IP $PORT 2>&1)
    CONNECTED=$(echo $CONNECTED | grep "succ")
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
    ((TICKS_PASSED++))
    if [[ $TICKS_PASSED -ge $TIMEOUT ]]; then
      break
    fi
  fi
done