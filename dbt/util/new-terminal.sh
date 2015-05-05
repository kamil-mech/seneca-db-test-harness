#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX" # <-- WARNING change manually when changing location
source $UTIL/tools.sh

CMD="$@"
ON_END="echo; echo DONE; read"
HANDLER="trap 'trap - EXIT; $ON_END' EXIT;"
nohup gnome-terminal --disable-factory -x bash -c "$HANDLER $CMD" >/dev/null 2>&1 &