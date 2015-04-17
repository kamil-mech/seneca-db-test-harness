INFO=$(docker inspect $1)

RESULT=""
for VAR in ${INFO[@]}; do
  if [[ "$VAR" == *"ExposedPorts"* ]]; then NEXT=2
  elif [[ "$NEXT" == 0 && "$VAR" != *"Hostname"* ]]; then
    RESULT+=" "$(echo $VAR | cut -d"/" -f1 | cut -d'"' -f2 | cut -d"{" -f1 | cut -d"}" -f1 )
  elif [[  "$VAR" == *"Hostname"* ]]; then echo ${RESULT[@]}; break; fi
  if [[ "$NEXT" > 0 ]]; then ((NEXT--)); fi
done