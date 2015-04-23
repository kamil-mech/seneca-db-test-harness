#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX" # <-- WARNING change manually when changing location
source $UTIL/tools.sh

FILE=$1

if [[ -d "$FILE" || -f "$FILE" ]]; then echo "true"
else echo "false"
fi