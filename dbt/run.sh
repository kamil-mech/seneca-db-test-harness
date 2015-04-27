#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX/util" # <-- WARNING change manually when changing location
source $UTIL/tools.sh
trap '' ERR # disable tools.error

echo -ne "\033]0;DBT Manager\007" # sets title

ARGS=$@
IFS=' ' read -ra ARGS <<< "$ARGS"
export CFGFILE="$PWD/${ARGS[0]}"
MOREARGS="${ARGS[1]}"
if [[ "$MOREARGS" == "" ]]; then
  ARGS=$npm_config_args
  IFS=' ' read -ra ARGS <<< "$ARGS"
fi

EEXIST=$(call "file-exist.sh" "$CFGFILE")
if [[ "$EEXIST" == false ]]; then error "NO CFG FILE"; fi

# read flags
FD=false
FB=false
TU=false
TA=false
NT=false
MAN=false
declare -a DEFAULT_DBS=("mem" "mongo" "jsonfile" "redis" "postgres" "mysql")
declare -a OBSOLETE_DBS=("cassandra")
declare -a MALFUNC_DBS=("fedora" "orient")
declare -a DBS=${DEFAULT_DBS[@]}
POPULATING=false
for VAR in "${ARGS[@]}"; do
  FCHAR="$(echo $VAR | head -c 1)"
  if [[ "$FCHAR" == "-" ]]; then POPULATING=false; fi
  
  if [[ "$VAR" == "-fd" ]]; then FD=true;
  elif [[ "$VAR" == "-fb" ]]; then FB=true;
  elif [[ "$VAR" == "-tu" ]]; then TU=true;
  elif [[ "$VAR" == "-ta" ]]; then TA=true;
  elif [[ "$VAR" == "-nt" ]]; then NT=true;
  elif [[ "$VAR" == "-man" ]]; then MAN=true;
  # dbs can be directly specified, no constraints
  elif [[ "$VAR" == "-dbs" ]]; then POPULATING=true; declare -a DBS=()
  elif [[ "$POPULATING" == true ]]; then
    # calculating multiplicity
    IFS='-' read -ra IN <<< "$VAR"
    DBTRIM="${IN[0]}"
    if [[ "$DBTRIM" == "all" ]]; then DBTRIM=${DEFAULT_DBS[@]}; fi
    IFS='x' read -ra IN <<< "${IN[1]}"
    TIMES=${IN[0]}
    if [[ "$TIMES" == "" ]]; then TIMES=1; fi
    while [[ $TIMES != 0 ]]
    do
    ((TIMES--))
    DBS+=($DBTRIM)
    done
  fi
done

declare -a LINKLESS=("mem" "jsonfile")
declare -a IGNORED=()

# generate conf
node "$UTIL/conf.js" "$CFGFILE"

# clean monitor data
rm -rf "$UTIL/log/"
rm -rf "$PREFIX/../log/"

IFS=" " read -ra DBS <<< "${DBS[@]}"
TOTAL_RUNS=${#DBS[@]}
CURRENT_RUN=0

echo "--------------------------------"
# main body that iterates over all dbs
for DB in ${DBS[@]}
do
  # feed progress on title bar
  ((CURRENT_RUN+=1))
  echo -ne "\033]0;DBT Manager ($CURRENT_RUN/$TOTAL_RUNS)\007" # sets title

  call "clean.sh" "${ARGS[@]}"

  # determine whether linked to db
  LINKED=true
  for VAR in ${LINKLESS[@]}
  do
    if [[ "$VAR" == "$DB" ]]; then LINKED=false; fi
  done

  # ensuring docker image and running it
  echo 
  echo "PREPARING $DB DB FOR TEST"
  if [[ "$LINKED" == true ]]; then 
    echo "USING DOCKER DB IMAGE FOR $DB"
    IMG_NAME=$DB
    if [[ "$IMG_NAME" == "cassandra" ]]; then IMG_NAME="spotify/cassandra"
    elif [[ "$IMG_NAME" == "couchdb" ]]; then IMG_NAME="fedora/couchdb"
    elif [[ "$IMG_NAME" == "orient" ]]; then IMG_NAME="superna/orientdb"
    fi
    call "image-check.sh" "$IMG_NAME" "$FD"

    # run db
    echo "RUN DB"
    if [[ "$DB" == "postgres" || "$DB" == "mysql" ]]; then
      nohup gnome-terminal --disable-factory -x bash -c "bash $PREFIX/dbs/$DB-init.sh" >/dev/null 2>&1 &

      sleep 2

      # loads DB_IP, DB_PORTS, DB_HEX and STREAMFILE vars
      source $UTIL/load-db-info.sh

      # wait for image to be up & listening
      call "examine-connection.sh" "$STREAMFILE" "$DB_IP" "$DB_PORTS"
    else      
      call "dockrunner.sh" "$DB" "--rm --name $DB-inst $IMG_NAME"
      
      # loads DB_IP, DB_PORTS, DB_HEX and STREAMFILE vars
      source $UTIL/load-db-info.sh
    fi

  else
    echo "USING SENECA-STORE_LISTEN FOR $DB"
  fi

  # running app, rebuild is optional
  if [[ "$TU" == false ]]; then
    IMAGES=$(docker images | grep well-app)
    if [[ "$FB" == true || "$IMAGES" == "" ]]; then
      echo "REBUILD THE APP"
      call "docker-build.sh"
      FB=false
    else
      echo "NO NEED TO REBUILD THE APP"
    fi

    # run app
    echo "RUN APP"
    DIMG=$(call "conf-obtain.sh" "dockimages" "-a")
    IMGNO=$(call "split.sh" "$DIMG" "@" "0")

    for (( I=1; I<=IMGNO; I+=1 ))
    do
      sleep 0.1

      IMG=$(call "split.sh" "$DIMG" "@" "$I")
      EXTRAS=""
      if [[ "$LINKED" == true ]]; then EXTRAS="--link $DB-inst:$DB-link --env db=$DB-store"; fi
      if [[ "$DB" == "rethinkdb" ]]; then DB="rethink"; fi
      EXTRAS+=" --env db=$DB-store"
      IMG="$EXTRAS $IMG"

      call "dockrunner.sh" "$DB" "$IMG"
    done
  else
    echo "NO NEED TO RUN THE APP FOR UNIT TEST"
  fi

  if [[ "$DB" == "rethinkdb" ]]; then DB="rethink"; fi
  #  run test
  if [[ "$NT" == false ]]; then
    echo
    echo "TEST $DB DB"
    call "/dockrunner.sh" "$DB" "; bash $UTIL/test.sh $DB $TU $TA $DB_IP $DB_PORTS"
  fi

  if [[ "$MAN" == false ]]; then
    # monitor for errors
    call "monitor.sh" "$DB"
    call "clean.sh" "${ARGS[@]} -last"
  else
    # prepare for next
    echo
    echo "TAP [ENTER] KEY TO"
    echo "STOP ALL AND CLEAN BEFORE NEXT"
    read
    echo
    call "clean.sh" "${ARGS[@]} -last -prompt"
  fi
done

echo -ne "\033]0;DBT Manager\007" # sets title

SUMMARY=$(call "summarize.sh")
echo "--------------------------------"
echo "$SUMMARY" > $UTIL/log/README.md
echo "$SUMMARY"
echo

# copy log folder to where it calls the script
call "ensure.sh" "$PREFIX/../log/"
mv "$UTIL/log"/* "$PREFIX/../log" 
rm -rf "$UTIL/log"