#!/bin/bash
trap 'kill $$' SIGINT
echo -ne "\033]0;DBT Manager\007" # sets title

# get dbt workdir path
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo
echo WORKDIR $PREFIX

ARGS=$@
IFS=' ' read -ra ARGS <<< "$ARGS"
export CFGFILE="$PWD/${ARGS[0]}"
MOREARGS="${ARGS[1]}"
if [[ "$MOREARGS" == "" ]]; then
  ARGS=$npm_config_args
  IFS=' ' read -ra ARGS <<< "$ARGS"
fi

EEXIST=$(bash $PREFIX/util/file-exist.sh $CFGFILE)
if [[ "$EEXIST" = false ]]; then echo "ERROR: NO CFG FILE"; exit 1; fi

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
for VAR in "${ARGS[@]}"
do
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
node $PREFIX/util/conf.js $CFGFILE

# clean monitor data
rm -rf $PREFIX/util/log/

echo "--------------------------------"

# main body that iterates over all dbs
for DB in ${DBS[@]}
do
  bash $PREFIX/clean.sh "${ARGS[@]}"

  # determine whether linked to db
  LINKED=true
  for VAR in ${LINKLESS[@]}
  do
    if [[ "$VAR" == "$DB" ]]; then LINKED=false; fi
  done

  # ensuring docker image and running it
  echo 
  echo PREPARING $DB DB FOR TEST
  if [[ "$LINKED" == true ]]; then 
    echo USING DOCKER DB IMAGE FOR $DB
    IMG_NAME=$DB
    if [[ "$IMG_NAME" == "cassandra" ]]; then IMG_NAME="spotify/cassandra"
    elif [[ "$IMG_NAME" == "couchdb" ]]; then IMG_NAME="fedora/couchdb"
    elif [[ "$IMG_NAME" == "orient" ]]; then IMG_NAME="superna/orientdb"
    fi
    bash $PREFIX/util/image-check.sh $IMG_NAME $FD

    # run db
    echo RUN DB
    if [[ "$DB" == "postgres" || "$DB" == "mysql" ]]; then
      nohup gnome-terminal --disable-factory -x bash -c "bash $PREFIX/dbs/$DB-init.sh" >/dev/null 2>&1 &

      sleep 1

      # get db info
      DB_HEX=$(cat $PREFIX/util/temp/$(ls -a $PREFIX/util/temp | grep "$DB.hex.out"))
      DB_HEX=${DB_HEX:0:8}
      DB_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $DB_HEX)
      DB_PORT=$(bash $PREFIX/util/docker-port.sh $DB_HEX)

      # detect errors
      STREAMFILE="$PREFIX/util/temp/"$(ls -a $PREFIX/util/temp | grep "$DB.stream.out") # TODO this needs to be replaced
      PEEK=$(bash $PREFIX/util/peek.sh $STREAMFILE null true)

      # if no errors
      # wait for image to be up & listening
      if [[ "$PEEK" != "ERR" && "$PEEK" != "FIN" && "$DB_PORT" != "" ]]; then
        bash $PREFIX/util/wait-connect.sh $DB_IP $DB_PORT
      fi
    else      
      bash $PREFIX/util/dockrunner.sh "$DB" "--rm --name $DB-inst $IMG_NAME"
      
      # get db info
      DB_HEX=$(cat $PREFIX/util/temp/$(ls -a $PREFIX/util/temp | grep "$DB.hex.out"))
      DB_HEX=${DB_HEX:0:8}
      DB_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $DB_HEX)
      DB_PORT=$(bash $PREFIX/util/docker-port.sh $DB_HEX)
    fi

  else
    echo USING SENECA DB TEST HARNESS FOR $DB
  fi

  # running app, rebuild is optional
  if [[ "$TU" == false ]]; then
    IMAGES=$(docker images | grep well-app)
    if [[ "$FB" == true || "$IMAGES" == "" ]]; then
      echo REBUILD THE APP
      bash $PREFIX/util/docker-build.sh
      FB=false
    else
      echo NO NEED TO REBUILD THE APP
    fi

    # run app
    echo RUN APP
    DIMG=$(bash $PREFIX/util/conf-obtain.sh dockimages -a)
    IMGNO=$(bash $PREFIX/util/split.sh "$DIMG" "@" 0)

    for (( I=1; I<=IMGNO; I++ ))
    do
      sleep 0.1

      IMG=$(bash $PREFIX/util/split.sh "$DIMG" "@" $I)
      EXTRAS=""
      if [[ "$LINKED" == true ]]; then EXTRAS="--link $DB-inst:$DB-link --env db=$DB-store"; fi
      if [[ "$DB" == "rethinkdb" ]]; then DB="rethink"; fi
      EXTRAS+=" --env db=$DB-store"
      IMG="$EXTRAS $IMG"

      bash $PREFIX/util/dockrunner.sh "$DB" "$IMG"
    done
  else
    echo NO NEED TO RUN THE APP FOR UNIT TEST
  fi

  if [[ "$DB" == "rethinkdb" ]]; then DB="rethink"; fi
  #  run test
  if [[ "$NT" == false ]]; then
    echo
    echo TEST $DB DB
    bash $PREFIX/util/dockrunner.sh "$DB" "; bash $PREFIX/util/test.sh $DB $TU $TA $DB_IP $DB_PORT"
  fi

  if [[ "$MAN" == false ]]; then
    # monitor for errors
    bash $PREFIX/util/monitor.sh "$DB"
    bash $PREFIX/clean.sh "${ARGS[@]}" -last
  else
    # prepare for next
    echo
    echo "TAP [ENTER] KEY TO"
    echo "STOP ALL AND CLEAN BEFORE NEXT"
    read
    echo
    bash $PREFIX/clean.sh "${ARGS[@]}" -last -prompt
  fi

  echo "--------------------------------"
  echo
done