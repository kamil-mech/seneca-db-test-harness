#!/bin/bash
trap 'kill $$' SIGINT
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

IFS=" " read -ra ARGS <<< "$@" # from args to array
ARGS=${ARGS:${#ARGS[0]}}       # remove first arg
ARGS=$(echo ${ARGS[@]})        # back to string
if [[ "${ARGS[@]}" == "" || "${ARGS[@]}" == *"--args="* ]]; then ARGS=$npm_config_args; fi
IFS=" " read -ra ARGS <<< "$ARGS"

# fetch project name
PROJECT=$1
if [[ "$PROJECT" == "" || "$PROJECT" == *"--"* ]]; then PROJECT=${ARGS[0]}; fi
echo
echo "TESTING PROJECT $PROJECT"
echo "ARGS ARE ${ARGS[@]}"

EEXIST=$(bash $PREFIX/dbt/util/file-exist.sh $PREFIX/../$PROJECT)
if [[ "$EEXIST" = false ]]; then echo "ERROR: NO PROJECT"; exit 1; fi

# find options file
cd ../$PROJECT/
WORKDIR="$PWD"
FILES=$(ls $WORKDIR | grep "options")
IFS=' ' read -ra FILES <<< "$FILES"
FILE=${FILES[0]}
echo "READING OPTIONS FROM $FILE"

CLEAN=false
for VAR in "${ARGS[@]}"
do  
  if [[ "$VAR" == "-clean" ]]; then CLEAN=true; fi
done

# run DBT Manager
if [[ "$CLEAN" == false ]]; then bash $PREFIX/dbt/run.sh $FILE ${ARGS[@]}
else echo; bash $PREFIX/dbt/clean.sh $FILE -last ${ARGS[@]}
fi