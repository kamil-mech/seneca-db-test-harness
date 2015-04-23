#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX" # <-- WARNING change manually when changing location
source $UTIL/tools.sh

DB=$1

# generates path/filename
function name_of {
    NAME=$1
    TYPE=$2
    PATH="$PREFIX"
    if [[ "$TYPE" == "LOG" ]]; then PATH="$PATH/log"
    elif [[ "$TYPE" == "DB" ]]; then
      PATH="$PATH/log/meta"
      TYPE="LOG"
    else PATH="$PATH/temp"
    fi
    TYPE="$TYPE""_POSTFIX"
    TYPE=$(echo "${!TYPE}")
    FILE="$PATH/$NAME.$TYPE"
    echo $FILE
}
STREAM_POSTFIX="stream.out"
LOG_POSTFIX="full.log"
SCRIPT_POSTFIX="script.sh"

function id_of {
  RAW=$1

  META_FILE="$PREFIX/temp/$RAW.label_index.out"
  if [[ "$2" == "DB" ]]; then META_FILE="$PREFIX/log/meta/$RAW.label_index.out"; fi

  # ensure required temp file
  call "ensure.sh" "$META_FILE"

  # read current value
  LABEL_INDEX=$(cat $META_FILE)
  if [[ "$LABEL_INDEX" == "" ]]; then LABEL_INDEX=0; fi

  LABEL="[$LABEL_INDEX]$RAW"
  if [[ "$2" == "DB" ]]; then LOGFILE=$(name_of "$LABEL" DB)
  else LOGFILE=$(name_of "$LABEL" LOG)
  fi

  # ensure entity names don't overlap
  EEXIST=$(call "file-exist.sh" "$LOGFILE")
  while [[ "$EEXIST" == true ]]; do
    ((LABEL_INDEX+=1))
    echo "$LABEL_INDEX" > "$META_FILE"
    LABEL="[$LABEL_INDEX]$RAW"
    LOGFILE=$(name_of $LABEL LOG)
    EEXIST=$(call "file-exist.sh" "$LOGFILE")
  done

  echo "$LABEL_INDEX"  
}

# generates label based on image name
function label_of {

  IFS=" " read -ra NAME <<< "$@" # from args to array
  NAME=${NAME:${#NAME[0]}}       # remove first arg
  NAME=$(echo ${NAME[@]})        # back to string

  # get docker half only
  RAW=$(call "split.sh" "$NAME" ";" "0")

  TEMP=""
  for ARG in $RAW; do
    # consider only ones that don't start with a dash
    FCHAR="$(echo $ARG | head -c 1)"
    if [[ "$FCHAR" != "-" ]]; then TEMP+="$ARG "; fi
  done
  RAW=$(echo $TEMP | tr '/' '-')

  RAW=$(echo $RAW | rev)
  RAW=$(call "split.sh" "$RAW" " " "0")
  RAW=$(echo $RAW | rev)
  if [[ "$RAW" == "LABEL" ]]; then RAW="script"; fi

  # resolve label ID
  LABEL_INDEX=$(id_of $RAW)
  LABEL="[$LABEL_INDEX]$RAW"

  echo $LABEL
}

call "ensure.sh" "$PREFIX/log/"
call "ensure.sh" "$PREFIX/temp/"

DB_LABEL_INDEX=$(id_of "$DB-db" DB)
DB_LABEL="[$DB_LABEL_INDEX]$DB-db"

# ensure required folders
declare -a FOLDERS=("$PREFIX/log/success" "$PREFIX/log/fail"
                    "$PREFIX/log/$DB_LABEL/" "$PREFIX/log/$DB_LABEL/success"
                    "$PREFIX/log/$DB_LABEL/fail")
for FOLDER in ${FOLDERS[@]}
do
  call "ensure.sh" "$FOLDER"
done

# allow other scripts to request filename and label
# this ensures naming is consistent across the entire system
if [[ "$2" == "NAME" ]]; then
  echo $(name_of $3 $4)
  exit 0
elif [[ "$2" == "LABEL" ]]; then
  echo $(label_of $@)
  exit 0
fi

# main body
echo "MONITORS UP"
call "ensure.sh" "$(name_of "$DB_LABEL" DB)"
while [[ true ]]; do

  sleep 1
  printf "."

  # error detecting
  ERRNO=0
  SUCCNO=0
  declare -a ERRLIST=()
  LOGS=$(ls $PREFIX/log/*.full.log)
  for LOG in ${LOGS[@]}
  do
    PEEK=""

    RAW=$(echo $LOG | rev)
    RAW=$(call "split.sh" "$RAW" "/" "0")
    RAW=$(echo $RAW | rev)
    RAW=$(call "split.sh" "$RAW" "." "0")

    STREAM="$PREFIX/temp/$RAW.$STREAM_POSTFIX"
    # peek
    EEXIST=$(call "file-exist.sh" "$STREAM")
    if [[ "$EEXIST" == true ]]; then PEEK=$(call "peek.sh" "$STREAM" "$LOG"); fi
    if [[ "$PEEK" == *"ERR"* ]]; then
      ((ERRNO+=1))
      ERRLIST+=("$RAW")
    elif [[ "$PEEK" == *"FIN"* ]]; then ((SUCCNO+=1))
    fi
  done

  # error handling
  if [[ "$ERRNO" > 0 ]]; then 
    CONFIRM=false
    echo
    echo "$ERRNO TERMINALS EXPERIENCED ERRORS [ ${ERRLIST[@]} ]."
    # all "confirm.sh" "NEXT TEST?"
    # CONFIRM=$(all "read-inspect.sh" "confirm")
    # if [[ "$CONFIRM" = true ]]; then
    #   echo "OK THEN. NEXT TEST"

      break
    # fi
  elif [[ "$SUCCNO" > 0 ]]; then echo; echo "SEEMS FINISHED"; break
  fi
done

# cleanup
call "kill-containers.sh"
FAILED=false
LOGS=$(ls $PREFIX/log/*.full.log)
for LOG in ${LOGS[@]}
do
  RAW=$(echo $LOG | rev)
  RAW=$(call "split.sh" "$RAW" "/" "0")
  RAW=$(echo $RAW | rev)
  RAW=$(call "split.sh" "$RAW" "." "0")

  # ensure logs are full and streamfiles are empty
  STREAM="$PREFIX/temp/$RAW.$STREAM_POSTFIX"

  EEXIST=$(call "file-exist.sh" "$STREAM")
  if [[ "$EEXIST" = true ]]; then TEMP=$(call "peek.sh" "$STREAM" "$LOG"); fi

  # produce feedback
  SUCC_PATH="$PREFIX/log/$DB_LABEL/success"
  FAIL_PATH="$PREFIX/log/$DB_LABEL/fail"
  LOG_DATA=$(cat $LOG)
  PEEK=$(call "peek.sh" "$LOG" "/dev/null")

  if [[ "$PEEK" == *"ERR"* ]]; then
    FINAL_LOG="$FAIL_PATH/$RAW.$LOG_POSTFIX"
    > $FINAL_LOG
    echo "$LOG_DATA" > $FINAL_LOG
    FAILED=true
  else
    FINAL_LOG="$SUCC_PATH/$RAW.$LOG_POSTFIX"
    > $FINAL_LOG
    echo "$LOG_DATA" > $FINAL_LOG
  fi
done

# place db log folder in success or fail respectively
if [[ "$FAILED" == false ]]; then
  mv "$PREFIX/log/$DB_LABEL/success"/* "$PREFIX/log/$DB_LABEL/"
  rm -rf "$PREFIX/log/$DB_LABEL/success"
  rm -rf "$PREFIX/log/$DB_LABEL/fail"
  TARGET="$PREFIX/log/success/$DB_LABEL/"
else
  TARGET="$PREFIX/log/fail/$DB_LABEL/"
fi
EEXIST=$(call "file-exist.sh" "$TARGET")
if [[ "$EEXIST" = false ]]; then mkdir "$TARGET"; fi

mv "$PREFIX/log/$DB_LABEL"/* "$TARGET"

echo "MONITORS DOWN"