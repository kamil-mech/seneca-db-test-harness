#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX/util" # <-- WARNING change manually when changing location
source $UTIL/tools.sh

ARGS=$@
IFS=' ' read -ra ARGS <<< "$ARGS"
if [[ "$CFGFILE" == "" ]]; then export CFGFILE="$PWD/${ARGS[0]}"; fi
MOREARGS="${ARGS[1]}"
if [[ "$MOREARGS" == "" ]]; then
    ARGS=$npm_config_args
    IFS=' ' read -ra ARGS <<< "$ARGS"
fi

EEXIST=$(call "file-exist.sh" "$UTIL/temp.conf.out")
if [[ "$EEXIST" = false ]]; then node $UTIL/conf.js $CFGFILE; fi

PROMPT=false
NER=false
AER=false
LAST=false
TIMG=false
for VAR in "${ARGS[@]}"
do
  if [[ "$VAR" = "-prompt" ]]; then PROMPT=true
  elif [[ "$VAR" = "-ner" ]]; then NER=true
  elif [[ "$VAR" = "-aer" ]]; then AER=true
  elif [[ "$VAR" = "-last" ]]; then LAST=true
  elif [[ "$VAR" = "-timg" ]]; then TIMG=true
  fi
done

call "kill-containers.sh"
call "kill-other-gnome.sh"

echo "ERASING TEMP"
 # TODO change
call "ensure.sh" "$UTIL/temp/"
rm -rf $UTIL/temp/*

if [[ "$NER" == false ]]; then
  echo
  echo "CLEANING AFTER LAST DB TEST"
  echo "YOU CAN USE -ner FLAG TO NEVER ERASE CUSTOM FILES"
  echo "OR -aer FLAG TO ALWAYS ERASE WITHOUT PROMPT (CAREFUL - CAN DESTROY HUMANITY!)"
  echo "IT IS ADVISED TO SET -aer FLAG AFTER SUCCESSFUL RUN WITHOUT IT"
  echo
  
  echo "ORPHANED DOCKER VOLUMES TAKE ENORMOUS AMOUNTS OF SPACE"
  CONFIRM=false
  if [[ "$AER" == false ]]; then
    call "confirm.sh" "ERASE DOCKER BLOAT AT /var/lib/docker/vfs/dir ?"
    CONFIRM=$(call "read-inspect.sh" "confirm")
  fi
  if [[ "$CONFIRM" = true || "$AER" == true ]]; then
    echo "ERASING DOCKER BLOAT AT /var/lib/docker/vfs/dir"
    sudo rm -rf /var/lib/docker/vfs/dir
  fi
  CONFIRM=false
  if [[ "$AER" == false ]]; then
    call "confirm.sh" "ERASE DOCKER BLOAT AT /var/lib/docker/volumes ?"
    CONFIRM=$(call "read-inspect.sh" "confirm")
  fi
  if [[ "$CONFIRM" = true || "$AER" == true ]]; then
    echo "ERASING DOCKER BLOAT AT /var/lib/docker/volumes"
    sudo rm -rf /var/lib/docker/volumes
  fi

  WORKDIR=$(call "conf-obtain.sh" "app" "workdir")
  CFILES=$(call "conf-obtain.sh" "cleanups" "-a")

  CNO=$(call "split.sh" "$CFILES" "@" "0")
  if [[ "$CNO" != "" && "$CNO" > 0 ]]; then
    for (( I=1; I<=CNO; I+=1 ))
    do
      CFILE=$(call "split.sh" "$CFILES" "@" "$I")
      CFILE=$(echo $CFILE | xargs) # trims whitespace
      if [[ "$CFILE" == "." || "$CFILE" == *".."* 
         || "$CFILE" == *".git"* || "$WORKDIR/$CFILE" == "$WORKDIR"
         || "$WORKDIR/$CFILE" == *"$PREFIX"* || "$PREFIX" == *"$WORKDIR/$CFILE"* ]]; then
        echo "[DANGEROUS SYNTAX] REFUSE TO DELETE $CFILE"
        continue
      fi

      CONFIRM=false
      if [[ "$AER" == false ]]; then
        call "confirm.sh" "ERASE $WORKDIR/$CFILE ?"
        CONFIRM=$(call "read-inspect.sh" "confirm")
      fi
      if [[ "$CONFIRM" = true || "$AER" == true ]]; then
        echo "ERASING $WORKDIR/$CFILE"
        sudo rm -rf $WORKDIR/$CFILE
      fi
    done
  fi
else
  echo
  echo "OMIT CUSTOM FILE ERASE"
  echo
fi

if [[ "$TIMG" == true ]]; then call "clean-images.sh"; TIMG=false; fi

if [[ "$PROMPT" = true ]]; then
    echo
    echo "NOTE: IT IS SAFE TO [CTRL]+[C] NOW"
    echo "ALL CLEAR. TAP [ENTER] KEY TO CONTINUE"
    read
fi
echo

if [[ "$LAST" == true ]]; then
  rm "$UTIL/temp.conf.out"

  EEXIST=$(call "file-exist.sh" "$UTIL/log")
  if [[ "$EEXIST" = true ]]; then ALL=$(ls $UTIL/log/)
  else ALL=""
  fi

  for VAR in ${ALL[@]}; do
    VAR="$UTIL/log/$VAR"
    if [[ "$VAR" != *"fail"* && "$VAR" != *"success"* && "$VAR" != *"meta"* ]]; then  rm -rf $VAR; fi
  done
fi