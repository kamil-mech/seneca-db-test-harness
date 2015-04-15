#!/bin/bash
trap 'kill $$' SIGINT
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#
# dockrunner supports monitoring and after-scripts
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
FULL_LENGTH=${#IMG}
PREFIX_LENGTH=${#RAWIMG}
SCRIPTS=${IMG:PREFIX_LENGTH:FULL_LENGTH}
echo "#!/bin/bash" > "$SCRIPT_FILE"
echo "echo $SCRIPTS" >> "$SCRIPT_FILE" 

# setup the command to be ran
HANDLER="trap 'trap - EXIT; echo; echo DONE; echo MONITOR-FIN >> $STREAMFILE; read;' EXIT;"
if [[ "$RAWIMG" == "" ]]; then DOCKER="echo"
else DOCKER="docker run $RAWIMG 2>&1 | tee -a $STREAMFILE"  
fi
SCRIPT="; bash $SCRIPT_FILE 2>&1 | tee -a $STREAMFILE"
COMMAND="$HANDLER $DOCKER $SCRIPT"

# determine terminal title

if [[ "$SCRIPTS" == *"test"* ]]; then
  TITLE="Test"

  # fixes label, but needs to be compatible with monitor
  # CLASSIFICATION=$(bash $PREFIX/split.sh "$LABEL" "]" 1)
  # ID=$(bash $PREFIX/split.sh "$LABEL" "$CLASSIFICATION" 0)
  # if [[ "$CLASSIFICATION" == "instance" ]]; then LABEL="$ID""test"; fi
elif [[ "$RAWIMG" == *"--link"* && "$RAWIMG" == *"-inst"* && "$RAWIMG" == *"-link"* ]]; then
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

# run
nohup gnome-terminal --title="$TITLE" --disable-factory -x bash -c "$COMMAND" >/dev/null 2>&1 &

# spawn cooldown
sleep 2

# get port info
for PARAM in $RAWIMG[@]; do
  if [[ "$PARAM}" == *"-p"* ]]; then NEXT=true
  elif [[ "$NEXT" == true ]]; then
    PORT="$PARAM"
    PORT=$(bash $PREFIX/split.sh "$PORT" ":" 0)
    break
  fi
done

# detect errors
PEEK=$(bash $PREFIX/peek.sh $STREAMFILE $LOGFILE true)

> $PREFIX/temp.hex.out
> $PREFIX/temp.ip.out
# check if image is up & listening
if [[ "$PEEK" != "ERR" && "$PEEK" != "FIN" && "$PORT" != "" ]]; then

  bash $PREFIX/docker-inspect.sh "$LABEL" $PORT
  HEX=$(bash $PREFIX/read-inspect.sh -nk hex)
  IP=$(bash $PREFIX/read-inspect.sh -nk ip)
  bash $PREFIX/wait-connect.sh $IP $PORT
fi
