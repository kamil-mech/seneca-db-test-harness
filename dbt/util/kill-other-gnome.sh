#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX" # <-- WARNING change manually when changing location
source $UTIL/tools.sh

echo KILLING TERMINALS

PIDS=$(pidof gnome-terminal)

TAB=$(echo -e '\t')

PARENT_GNOME="$$"
while [[ "$(ps -f $PARENT_GNOME)" != *"gnome-terminal"* ]]; do
  PARENT_GNOME=$(echo $(ps -f -o ppid $PARENT_GNOME | awk -F"PPID" '{print $1}'))
done

for VAR in $PIDS{@}
do
  VAR=$(echo $VAR | awk -F"{@}" '{print $1}')
  if [[ "$VAR" != "$PARENT_GNOME" ]]; then
    echo $VAR
    kill $VAR
  fi
  ((I+=1))
done