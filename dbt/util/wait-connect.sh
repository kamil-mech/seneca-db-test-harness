#!/bin/bash
trap 'kill $$' SIGINT

IP=$1
IFS=" " read -ra PORTS <<< "$@"   # from args to array
PORTS=${PORTS:${#PORTS[0]}}       # remove first arg
IGNORED_PORTS=("7199" "7000")

# declare -i TIMEOUT=$3
# declare -i TICKS_PASSED=0

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
    echo VALUE IS $CONNECTED
    echo "SUCCESS @ $WINNER"
    break
  fi

  # if [[ "$TIMEOUT" != "0" ]]; then
  #   echo TICK
  #   echo $TICKS_PASSED
  #   ((TICKS_PASSED++))
  #   echo $TICKS_PASSED
  #   if [[ $TICKS_PASSED -gt $TIMEOUT ]]; then
  #     echo TIMEOUT
  #     break
  #   fi
  # fi
done
echo