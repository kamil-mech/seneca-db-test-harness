#!/bin/bash

docker kill $(docker ps -a -q)
docker rm $(docker ps -a -q)

echo "TOP PARENT: $1"
ALL="$(pgrep -P $1)"

if [[ "$ALL" != *"Usage"* ]]; then
  for CHILD in ${ALL[@]}; do
    echo "CHILD $CHILD"
    SUB="$(pgrep -P $CHILD)"
    for SUBCHILD in ${SUB[@]}; do
      echo "SUBCHILD $SUBCHILD"
      # kill $SUBCHILD
      SUB_2="$(pgrep -P $SUBCHILD)"
      for SUB_2_CHILD in ${SUB_2[@]}; do
        echo "KILLING $SUB_2_CHILD"
        kill $SUB_2_CHILD
      done
      kill $SUBCHILD
    done
    kill $CHILD
  done
fi