echo "ARGS $@"
declare -i i=0
while [[ true ]]; do
  if [[ "$i" -eq 3 ]]; then
    echo "ERROR"
  elif [[ "$i" -eq 7 ]]; then
    cat 1
  elif [[ "$i" -eq 10 ]]; then
    echo "DONE"
    exit 1
  else
    echo "GOOD"
  fi
  sleep 0.5
  ((i+=1))
done