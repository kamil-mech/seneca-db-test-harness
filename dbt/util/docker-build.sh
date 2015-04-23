#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX" # <-- WARNING change manually when changing location
source $UTIL/tools.sh

WORKDIR=$(call "conf-obtain.sh" "app" "workdir")

DFILES=$(call "conf-obtain.sh" "dockbuilds" "-a")
FILENO=$(call "split.sh" "$DFILES" "@" "0")

for (( I=1; I<=FILENO; I+=1 ))
do
  FILE=$(call "split.sh" "$DFILES" "@" "$I")
  IMGNAME=$(call "split.sh" "$FILE" " " "0")
  IMGLOC=$(call "split.sh" "$FILE" " " "1")
  docker build --force-rm -t $IMGNAME $WORKDIR/$IMGLOC
done