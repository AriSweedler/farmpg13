function item::num_to_name() {
  local -r num="$1"
  local -r item_name=$(jq -r '. as $json | keys[] | select($json[.] == "'"${num}"'")' "./scraped/item_to_number.json")

  if [ -z "$item_name" ]; then
    log::err "Could not find item name for number $num"
    exit 1
  fi

  printf "%s" "$item_name"
}

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

function fish::loc_to_num() {
  local -r loc_name="$(echo "${1:?}" | tr '-' '_')"
  local -r loc_nr="$(jq -r '.["'"$loc_name"'"]' "./scraped/fishloc_to_number.json")"
  if [ "$loc_nr" == "null" ]; then
    log::err "Could not turn fishing location into a number | loc_nr='$loc_nr' item_name='$item_name'"
    printf "0"
    exit 1
  elif [ "$loc_nr" == "-1" ]; then
    log::err "You cannot fish there yet"
    printf "0"
    exit 1
  fi

  printf "%s" "$loc_nr"
}

function item_nr_to_name() {
  local -r item_nr="${1:?}"
  jq -r \
    --arg value "$item_nr" \
    'to_entries[] | select(.value == $value) | .key' \
    "./scraped/item_to_number.json"
}
