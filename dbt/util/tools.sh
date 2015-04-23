#!/bin/bash

# color scheme
red='\033[0;31m'
NC='\033[0m' # no color

trap 'kill $$' SIGINT;

function error {
  if [[ "$1" == "" ]]; then printf "    at "; fi
  IFS='/' read -ra FILE <<< "$(echo $0 | rev)"
  echo -e "${red}ERROR${NC} ($(echo ${FILE[0]} | rev)[$BASH_LINENO]): ""$1"
  if [[ "$2" != "NOEXIT" ]]; then exit 1; fi
}
trap 'error ""' ERR;

function call {
  LOC="$PREFIX/$1"
  EEXIST=$(bash $UTIL/file-exist.sh $LOC)
  if [[ "$EEXIST" == false ]]; then LOC="$UTIL/$1"; EEXIST=$(bash $UTIL/file-exist.sh $LOC); fi
  if [[ "$EEXIST" == false ]]; then error "SCRIPT NOT FOUND [$1]"; fi
  bash $LOC "${@:2}"
}