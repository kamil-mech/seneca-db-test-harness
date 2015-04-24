#!/bin/bash

# color scheme
red='\033[0;31m'
NC='\033[0m' # no color

trap 'kill $$' SIGINT;

function parent_file {
  IFS='/' read -ra FILE <<< "$(echo $0 | rev)"
  FILE=$(echo ${FILE[0]} | rev)
  echo $FILE
}

function throw {
  if [[ "$1" == *"FETCH-ERROR"* ]]; then error "$1"
  elif [[ "$1" == *"ERROR"* ]]; then error ""
  fi
}

function error {  

  if [[ "$1" == "" ]]; then printf "    at " ;
  else echo
  fi

  FILE=$(parent_file)

  ERR="${red}ERROR${NC}"
  if [[ "$BLINE" == "" ]]; then BLINE="$BASH_LINENO"; fi

  if [[ "$2" != *"REF"* ]]; then echo -e "$ERR (${FILE[0]})[$BLINE]): ""$1"
  else echo -e "$ERR ($1)"
  fi
  
  if [[ "$2" != *"NOEXIT"* ]]; then exit 1; fi
}
trap 'error ""' ERR;

function find_n_run {
  # identify script
  LOC="$PREFIX/$1"
  EEXIST=$(bash $UTIL/file-exist.sh $LOC)
  if [[ "$EEXIST" == false ]]; then LOC="$UTIL/$1"; EEXIST=$(bash $UTIL/file-exist.sh $LOC); fi
  if [[ "$EEXIST" == false ]]; then error "SCRIPT NOT FOUND: $1"; fi

  # setup log
  EEXIST=$(bash $UTIL/file-exist.sh $UTIL/temp/ | tail -1)
  if [[ "$EEXIST" == false ]]; then mkdir "$UTIL/temp"; fi
  bash $LOC "${@:2}" | tee "$UTIL/temp/$1.log"
}

# fetch is always going to be used in a subshell $()
# only used by call, should not be used on its own
function fetch {
  LOC="$UTIL/temp/$1.log"
  EEXIST=$(bash $UTIL/file-exist.sh $LOC | tail -n5)
  if [[ "$EEXIST" == false ]]; then echo "FETCH-ERROR: CANNOT FETCH $LOC. NO FILE"
  else
    OUTPUT=$(cat "$LOC")
    rm "$LOC"
    echo "$OUTPUT"
  fi
}

function call {
  BLINE="$BASH_LINENO"
  FEEDBACK=""
  find_n_run $@; FEEDBACK=$(fetch "$1"); throw "$FEEDBACK"
}