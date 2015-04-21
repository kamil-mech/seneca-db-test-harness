#!/bin/bash
trap 'kill $$' SIGINT
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#
# dockrunner supports monitoring and after-scripts
# it also ensures listen/crash takes place
#

# fetch db info
IFS=" " read -ra IMG <<< "$@" # from args to array
DB=${IMG[0]}                  # obtain DB 
IMG=${IMG:${#IMG[0]}}         # remove first arg
IMG=$(echo ${IMG[@]})         # back to string

LABEL=$(bash $PREFIX/monitor.sh $DB LABEL $IMG)
if [[ "$LABEL" == *"$DB"* ]]; then echo "BOOTING $LABEL"
else echo "BOOTING $LABEL WITH $DB DB"
fi

# init monitoring
LOGFILE=$(bash $PREFIX/monitor.sh $DB NAME $LABEL LOG)
> "$LOGFILE" # creates empty or empties path/file
STREAMFILE=$(bash $PREFIX/monitor.sh $DB NAME $LABEL STREAM)
> "$STREAMFILE"
SCRIPT_FILE=$(bash $PREFIX/monitor.sh $DB NAME $LABEL SCRIPT)
> "$SCRIPT_FILE"

# separate scripts and docker
declare -a RAWIMG=$(bash $PREFIX/split.sh "$IMG" ";" 0) # contains flags and args
# docker generates file containing hex id of container when --cidfile is specified
if [[ "$RAWIMG" != "" ]]; then
  IMG="--cidfile='$PREFIX/temp/$LABEL.hex.out' $IMG"
  declare -a RAWIMG=$(bash $PREFIX/split.sh "$IMG" ";" 0) # update
fi

FULL_LENGTH=${#IMG}
PREFIX_LENGTH=${#RAWIMG}
SCRIPTS=${IMG:PREFIX_LENGTH:FULL_LENGTH}
echo "#!/bin/bash" > "$SCRIPT_FILE"
echo "echo $SCRIPTS" >> "$SCRIPT_FILE" 

# determine terminal title
if [[ "$SCRIPTS" == *"test"* ]]; then
  TITLE="Test"

  # fixes label, but needs to be compatible with monitor
  # CLASSIFICATION=$(bash $PREFIX/split.sh "$LABEL" "]" 1)
  # ID=$(bash $PREFIX/split.sh "$LABEL" "$CLASSIFICATION" 0)
  # if [[ "$CLASSIFICATION" == "script" ]]; then LABEL="$ID""test"; fi
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


# spawn cooldown
sleep 2

# get container info
if [[ "$LABEL" != *"script"* ]]; then
  HEX=$(cat $PREFIX/temp/$LABEL.hex.out)
  HEX=${HEX:0:8}
  IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $HEX)
  PORTS=$(bash $PREFIX/docker-port.sh $HEX)
  echo "$LABEL DETAILS:"
  echo "$LABEL DOCKER HEX $HEX"
  echo "$LABEL ADDR $IP"
  echo "@ PORTS: $PORTS"
  echo

  # detect errors
  PEEK=$(bash $PREFIX/peek.sh $STREAMFILE $LOGFILE true)

  # if no errors
  # wait for image to be up & listening
  if [[ "$PEEK" != "ERR" && "$PEEK" != "FIN" && "$PORTS" != "" ]]; then
    bash $PREFIX/wait-connect.sh 2 $IP $PORTS
    PEEK=$(bash $PREFIX/peek.sh $STREAMFILE $LOGFILE true)
  fi
fi