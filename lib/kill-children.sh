#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

echo "TOP PARENT: $1"

docker kill $(docker ps -a -q) || true
docker rm $(docker ps -a -q) || true

# recursive
function kill_children(){
  echo "PROCESS: $1"
  # check more
  ALL="$(pgrep -P $1 || true)"

  if [[ "$ALL" != "" && "$ALL" != *"Usage"* ]]; then
    for CHILD in ${ALL[@]}; do
      kill_children "$CHILD"
      # kill
      echo "KILLING $CHILD"
      kill "$CHILD" &> /dev/null || true
    done
  fi
}

kill_children $1

