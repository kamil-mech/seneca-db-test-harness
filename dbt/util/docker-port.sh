INFO=$(docker inspect $1)
for VAR in ${INFO[@]}; do
  if [[ "$VAR" == *"ExposedPorts"* ]]; then NEXT=2
  elif [[ "$NEXT" == 0 ]]; then echo $(echo $VAR | cut -d"/" -f1 | cut -d'"' -f2); break; fi
  ((NEXT--))
done