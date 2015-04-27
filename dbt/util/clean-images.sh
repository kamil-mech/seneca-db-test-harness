echo "REMOVING TRASH IMAGES"

imgs=$(docker images)

nometer=0
for i in ${imgs[@]}; do
  if [[ "$nometer" -ge 2 ]]; then
    nometer=0
    docker rmi -f "$i"
  elif [[ "$i" == *"<none>"* ]]; then ((nometer+=1))
  fi
done