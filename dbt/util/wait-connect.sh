#!/bin/bash
trap 'kill $$' SIGINT

IP=$1
PORT=$2
declare -i TIMEOUT=$3
declare -i TICKS_PASSED=0

echo CONNECTING TO $IP:$PORT
while [[ true ]]; do
    CONNECTED=$(nc -z -v -w 1 $IP $PORT 2>&1)
    CONNECTED=$(echo $CONNECTED | grep "succ")
    if [[ "$CONNECTED" = "" ]]; then
      printf '.'
      sleep 1
    else
      echo
      echo SUCCESS
      break
    fi

    if [[ "$TIMEOUT" != "0" ]]; then
      echo TICK
      echo $TICKS_PASSED
      ((TICKS_PASSED++))
      echo $TICKS_PASSED
      if [[ $TICKS_PASSED -gt $TIMEOUT ]]; then
        echo TIMEOUT
        break
      fi
    fi
done
echo