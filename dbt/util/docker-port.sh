#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX" # <-- WARNING change manually when changing location
source $UTIL/tools.sh

HEX=$1
if [[ "$HEX" == "" ]]; then error "NO HEX SPECIFIED"; fi
INFO=$(docker inspect $HEX)

RESULT=""
for VAR in ${INFO[@]}; do
  if [[ "$VAR" == *"ExposedPorts"* ]]; then NEXT=2
  elif [[ "$NEXT" == 0 && "$VAR" != *"Hostname"* ]]; then
    RESULT+=" "$(echo $VAR | cut -d"/" -f1 | cut -d'"' -f2 | cut -d"{" -f1 | cut -d"}" -f1 )
  elif [[  "$VAR" == *"Hostname"* ]]; then echo ${RESULT[@]}; break; fi
  if [[ "$NEXT" > 0 ]]; then ((NEXT--)); fi
done