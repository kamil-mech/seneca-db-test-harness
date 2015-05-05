#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX" # <-- WARNING change manually when changing location
source $UTIL/tools.sh
trap '' ERR # disable error handler

DB="$1"
LEADING_FILE="$2"
LOG_PATH="$UTIL/log"

# increment DB log folder, if preexist
INDEX=0
while [[ true ]]; do
  DB_LABEL="[$INDEX]$DB"
  DB_PATH="$LOG_PATH/$DB_LABEL"
  
  EEXIST=$(call "file-exist.sh" "$DB_PATH")
  if [[ "$EEXIST" == false ]]; then break; fi
    ((INDEX+=1))
done

# build dir tree
FINISH_PATH="$DB_PATH/finished"
CRASH_PATH="$DB_PATH/crashed"
INTERRUPT_PATH="$DB_PATH/interrupted"
call "ensure.sh" "$FINISH_PATH"
call "ensure.sh" "$CRASH_PATH"
call "ensure.sh" "$INTERRUPT_PATH"

# wait until first finish/crash take place
while [[ true ]]; do
  FILES=$(ls "$LOG_PATH")
  if [[ "${FILES[@]}" == *".fin"* || "${FILES[@]}" == *".err"* ]]; then break; fi
done

# stop all
call "kill-other-gnome.sh"
sleep 1

# fetch log data
LOGFILES=$(echo "${FILES[@]}" | grep ".log")
FINFILES=$(echo "${FILES[@]}" | grep ".fin")
ERRFILES=$(echo "${FILES[@]}" | grep ".err")

# organise files
for FILE in ${LOGFILES[@]}; do
  LABEL="$(echo $FILE | rev | cut -c 5- | rev)"

  if [[ "${FINFILES[@]}" == *"$LABEL"* ]]; then
    # echo "$LABEL IS FIN"
    mv "$LOG_PATH/$FILE" "$FINISH_PATH"
  elif [[ "${ERRFILES[@]}" == *"$LABEL"* ]]; then
    # echo "$LABEL IS ERR"
    mv "$LOG_PATH/$FILE" "$CRASH_PATH"
    mv "$LOG_PATH"/*.err "$CRASH_PATH"
  else
    # echo "$LABEL IS INTERRUPTED"
    mv "$LOG_PATH/$FILE" "$INTERRUPT_PATH"
  fi
done

# feedback
echo
if [[ "${ERRFILES[@]}" != "" ]]; then echo "ERROR: CRASH DETECTED"
elif [[ "${FINFILES[@]}" != *"$LEADING_FILE"* ]]; then echo "ERROR: SHUTDOWN DETECTED BEFORE $LEADING_FILE FINISHED"
else echo "ALL CLEAR"
fi
echo

# cleanup
rm "$LOG_PATH"/*.fin