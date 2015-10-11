#!/bin/bash

docker kill $(docker ps -a -q)
docker rm $(docker ps -a -q)

ALL="$(pgrep -P $1)"
for CHILD in ${ALL[@]}; do
  SUB="$(pgrep -P $CHILD)"
  for SUBCHILD in ${SUB[@]}; do
   kill $SUBCHILD
  done  
done