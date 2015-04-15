#!/bin/bash
trap 'kill $$' SIGINT
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

STREAMFILE=$1
LOGFILE=$2
NOCHANGE=$3

# get data chunk
BUFFER=$(cat $STREAMFILE)
LCBUFFER=$(echo $BUFFER | tr '[:upper:]' '[:lower:]')

# update full log
if [[ "$NOCHANGE" != true ]]; then
  cat $STREAMFILE >> $LOGFILE
  > $STREAMFILE
fi

# detect error
if [[ "$LCBUFFER" == *"error"* ]]; then
  cat $STREAMFILE >> $LOGFILE
  echo "ERR"
else
  if [[ "$BUFFER" == *"MONITOR-FIN"* ]]; then echo "FIN"; fi
fi