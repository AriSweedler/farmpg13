function item::name_to_num() {
  local -r item_name="$(echo "${1:?}" | tr '-' '_')"
  local -r num="$(jq -r '.["'"$item_name"'"]' "./scraped/item_to_number.json")"
  if [ "$num" == "null" ]; then
    log::err "Could not turn item into number | num='$num'"
    printf "0"
    exit 1
  fi

  printf "%s" "$num"
}

function item::name_to_location() {
  local -r item_name="$(echo "${1:?}" | tr '-' '_')"
  local -r loc="$(jq -r '.["'"$item_name"'"]' "./scraped/item_to_location.json")"
  if [ "$loc" == "null" ]; then
    log::err "Could not turn item into a location | loc='$loc' item_name='$item_name'"
    printf "0"
    exit 1
  fi

  printf "%s" "$loc"
}

function item::location_to_num() {
  local -r loc="$(echo "${1:?}" | tr '-' '_')"
  local -r num="$(jq -r '.["'"$loc"'"]' "./scraped/location_to_number.json")"
  if [ "$num" == "null" ]; then
    log::err "Could not turn item into a location | num='$num'"
    printf "0"
    exit 1
  fi

  printf "%s" "$num"
}
