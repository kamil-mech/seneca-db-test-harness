#!/bin/bash
trap 'kill $$' SIGINT
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

declare -a NAMES=()
declare -A SCORES

# NAME="jsonfile-db"
# KEY="$NAME""_FAIL"
# SCORES[$KEY]=0
# echo HERE1: ${SCORES[$KEY]}
# ((SCORES[$KEY]++))
# echo HERE2: ${SCORES[$KEY]}

LOG_FOLDER="$PREFIX/log"
FAIL_FOLDER="$LOG_FOLDER/fail"
SUCCESS_FOLDER="$LOG_FOLDER/success"

declare -a CASES=("FAIL" "SUCCESS")
for CASE in ${CASES[@]}; do

  # get search location
  SEARCH_LOC="$CASE""_FOLDER"
  SEARCH_LOC=$(echo "${!SEARCH_LOC}")

  # for each folder in case
  FOLDERS=$(ls $SEARCH_LOC)
  for FOLDER in ${FOLDERS[@]}; do

    IFS=']' read -ra TEMP <<< "$FOLDER"
    NAME="${TEMP[1]}"
    IFS='-' read -ra TEMP <<< "$NAME"
    NAME="${TEMP[0]}"
    KEY="$NAME""_""$CASE"

    # if no entry, init
    if [[ "${NAMES[@]}" != *"$NAME"* ]]; then
      NAMES+="$NAME "

      SCORES[$KEY]=0
    fi

    # increment value
    ((SCORES[$KEY]++))
  done
done

# makes table look coherent. can be removed if laggs
LONGEST_NAME=0
LONGEST_SUCCESS=0
LONGEST_TOTAL=0
for NAME in ${NAMES[@]}; do
  # obtain success score
  KEY="$NAME""_""SUCCESS"
  SUCCESS=${SCORES[$KEY]}
  if [[ "$SUCCESS" == "" ]]; then SUCCESS=0; fi

  # obtain fail score
  KEY="$NAME""_""FAIL"
  FAIL=${SCORES[$KEY]}
  if [[ "$FAIL" == "" ]]; then FAIL=0; fi

  # compute total value
  TOTAL=$((SUCCESS + FAIL))

  if [[ "${#NAME}" -gt "$LONGEST_NAME" ]]; then LONGEST_NAME="${#NAME}"; fi
  if [[ "${#SUCCESS}" -gt "$LONGEST_SUCCESS" ]]; then LONGEST_SUCCESS="${#SUCCESS}"; fi
  if [[ "${#TOTAL}" -gt "$LONGEST_TOTAL" ]]; then LONGEST_TOTAL="${#TOTAL}"; fi
done

echo
# display number of fails / fail+succ
for NAME in ${NAMES[@]}; do

  # obtain success score
  KEY="$NAME""_""SUCCESS"
  SUCCESS=${SCORES[$KEY]}
  if [[ "$SUCCESS" == "" ]]; then SUCCESS=0; fi

  # obtain fail score
  KEY="$NAME""_""FAIL"
  FAIL=${SCORES[$KEY]}
  if [[ "$FAIL" == "" ]]; then FAIL=0; fi

  # compute values
  TOTAL=$((SUCCESS + FAIL))
  PERCENT=$(printf '%i %i' $SUCCESS $TOTAL | awk '{ pc=100*$1/$2; i=int(pc); print (pc-i<0.5)?i:i+1 }')


  function fix_indentation {
    STR=$1
    LENGTH=$2
    APPEND=$3
    if [[ "$LENGTH" == "" ]]; then LENGTH=15; fi

    while [[ "${#STR}" -lt "$LENGTH" ]]; do
      if [[ "$APPEND" == true ]]; then STR+=" "
      else STR=" $STR"
      fi
    done

    if [[ "$APPEND" == true ]]; then STR=" $STR"
    else STR+=" "
    fi

    echo "$STR"
  }

  # fix indentation
  NAME=" $(fix_indentation "$NAME" $LONGEST_NAME)"
  SUCCESS="$(fix_indentation "$SUCCESS" $LONGEST_SUCCESS)"
  TOTAL="$(fix_indentation "$TOTAL" $LONGEST_TOTAL true)"

  # display
  echo "$NAME SUCCESS RATE: $SUCCESS / $TOTAL ($PERCENT%)"
done
echo

# -----------------------------------------
# OPTIONAL: add a footer with sample errors