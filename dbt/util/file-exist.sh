#!/bin/bash
trap 'kill $$' SIGINT

FILE=$1

if [[ -d "$FILE" || -f "$FILE" ]]; then echo "true"
else echo "false"
fi