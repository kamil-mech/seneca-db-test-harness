#!/bin/bash
PREFIX="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
UTIL="$PREFIX" # <-- WARNING change manually when changing location
source $UTIL/tools.sh

MSG=$1

echo "$MSG (y/n)"
read
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then echo "true" > $PREFIX/temp.confirm.out
else echo "false" > $PREFIX/temp.confirm.out
fi
