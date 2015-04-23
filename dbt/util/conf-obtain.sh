#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX" # <-- WARNING change manually when changing location
source $UTIL/tools.sh

DB=$1
QUERY=$2
if [[ "$QUERY" == "-a" ]]; then
  OUTPUT=""
  OUTPUTLINES=0
fi

EEXIST=$(call "file-exist.sh" "$CFGFILE")
if [[ "$EEXIST" = false ]]; then node $PREFIX/conf.js $CFGFILE; fi

FILE=$(call "read-inspect.sh" "-nk" "conf")

# these conditions are a mess. need to clean them up
for ENTRY in ${FILE[@]}
do
  if [[ "$ENTRY" == *"@"* && "$INSIDE" = true ]]; then ((OUTPUTLINES+=1)); fi
  if [[ "$ENTRY" == "!" && "$INSIDE" = true ]]; then
    echo "$OUTPUTLINES $OUTPUT"
    break
  elif [[ "$ENTRY" == "$DB" ]]; then INSIDE=true
  elif [[ "$NEXTOUT" == true ]]; then
    if [[ "$QUERY" != "-a" ]]; then
      echo "$ENTRY"
      break
    else
      OUTPUT="$OUTPUT $ENTRY "
    fi
  elif [[ "$INSIDE" = true && "$ENTRY" == "$QUERY" ]]; then NEXTOUT=true
  elif [[ "$INSIDE" = true && "$QUERY" == "-a" ]]; then
    NEXTOUT=true
    OUTPUT="$OUTPUT $ENTRY "
  fi
done