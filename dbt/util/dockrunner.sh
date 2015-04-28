#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX" # <-- WARNING change manually when changing location
source $UTIL/tools.sh

#
# dockrunner supports monitoring and after-scripts
# it also ensures listen/crash takes place
#

# fetch db info
IFS=" " read -ra IMG <<< "$@" # from args to array
DB=${IMG[0]}                  # obtain DB 
IMG=${IMG:${#IMG[0]}}         # remove first arg
IMG=$(echo ${IMG[@]})         # back to string

call "ensure.sh" "$UTIL/temp"

LABEL=$(call "monitor.sh" "$DB" "LABEL" "$IMG")
if [[ "$LABEL" == *"$DB"* ]]; then echo "BOOTING $LABEL"
else echo "BOOTING $LABEL WITH $DB DB"
fi

# init monitoring
LOGFILE=$(call "monitor.sh" "$DB" "NAME" "$LABEL" "LOG")
> "$LOGFILE" # creates empty or empties path/file
STREAMFILE=$(call "monitor.sh" "$DB" "NAME" "$LABEL" "STREAM")
> "$STREAMFILE"
SCRIPT_FILE=$(call "monitor.sh" "$DB" "NAME" "$LABEL" "SCRIPT")
> "$SCRIPT_FILE"

# separate scripts and docker
declare -a RAWIMG=$(call "split.sh" "$IMG" ";" "0") # contains flags and args
# docker generates file containing hex id of container when --cidfile is specified
if [[ "$RAWIMG" != "" ]]; then
  IMG="--cidfile='$PREFIX/temp/$LABEL.hex.out' $IMG"
  declare -a RAWIMG=$(call "split.sh" "$IMG" ";" "0") # update
fi

FULL_LENGTH=${#IMG}
PREFIX_LENGTH=${#RAWIMG}
SCRIPTS=${IMG:PREFIX_LENGTH:FULL_LENGTH}
echo "#!/bin/bash" > "$SCRIPT_FILE"
echo "echo $SCRIPTS" >> "$SCRIPT_FILE" 

# determine terminal title
if [[ "$SCRIPTS" == *"test"* ]]; then
  TITLE="Test"
elif [[ "$RAWIMG" == *"--env"* ]]; then
  declare -a LINKLESS=("mem" "jsonfile")
  LINKED=true
  for LINK in ${LINKLESS[@]}
  do
      if [[ "$DB" == "$LINK" ]]; then LINKED=false; break; fi
  done
  TITLE="App"
  if [[ "$LINKED" == false ]]; then TITLE="App & Database - $DB"
  else EXTRAS="--link $DB-inst:$DB-link -e db=$DB-store"
  fi

else
  TITLE="Database - $DB"
fi
TITLE="$TITLE ($LABEL)"

# setup the command to be ran
ON_END="echo; echo DONE; echo MONITOR-FIN >> $STREAMFILE; read"
HANDLER="trap 'trap - EXIT; $ON_END' EXIT;"
if [[ "$RAWIMG" == "" ]]; then DOCKER="echo"
else DOCKER="docker run $RAWIMG 2>&1 | tee -a $STREAMFILE"  
fi
SCRIPT="; bash $SCRIPT_FILE 2>&1 | tee -a $STREAMFILE; $ON_END"
COMMAND="$HANDLER $DOCKER $SCRIPT"

# run
if [[ "$LABEL" == *"postgres"* || "$LABEL" == *"mysql"* ]]; then
  echo -ne "\033]0;$TITLE\007" # sets title
  bash -c "$COMMAND" &
else
  nohup gnome-terminal --title="$TITLE" --disable-factory -x bash -c "$COMMAND" >/dev/null 2>&1 &
fi

# get container info
I=0
if [[ "$LABEL" != *"script"* ]]; then
  while [[ true ]]; do
    ((I+=1))

    EEXIST=$(call "file-exist.sh" "$PREFIX/temp/$LABEL.hex.out")
    if [[ "$EEXIST" == true ]]; then HEX=$(cat $PREFIX/temp/$LABEL.hex.out); fi
    HEX=${HEX:0:8}
    if [[ "$HEX" != "" || "$I" > 3 ]]; then break; fi
    sleep 1
  done

  IP=$(call "docker-inspect.sh" "IP" "$HEX")
  PORTS=$(call "docker-inspect.sh PORTS" "$HEX")
  echo "$LABEL DETAILS:"
  echo "$LABEL DOCKER HEX $HEX"
  echo "$LABEL ADDR $IP"
  echo "@ PORTS: $PORTS"
  echo

  # wait for image to be up & listening
  call "examine-connection.sh" "$STREAMFILE" "$IP" "$PORTS"
fi