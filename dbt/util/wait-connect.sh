#!/bin/bash
trap 'kill $$' SIGINT

declare -i TIMEOUT=$1
declare -i TICKS_PASSED=0
IP=$2
IFS=" " read -ra PORTS <<< "$@"   # from args to array
PORTS=${PORTS:${#PORTS[1]}}       # remove first 2 args
IGNORED_PORTS=("7199" "7000")

echo
echo "CONNECTING TO $IP"
echo "@ PORTS: ${PORTS[@]}"
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
    break
  fi

  if [[ "$TIMEOUT" != "0" ]]; then
    ((TICKS_PASSED++))
    if [[ $TICKS_PASSED -ge $TIMEOUT ]]; then
      break
    fi
  fi
done
echo