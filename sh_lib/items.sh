function item::name_to_location() {
  local -r item_name="$(item::new::name "${1:?}")"
  local -r loc="$(jq -r '.["'"$item_name"'"]' "./scraped/item_to_location.json")"
  if [ "$loc" == "null" ]; then
    log::err "Could not turn item into a location | loc='$loc' item_name='$item_name'"
    printf "0"
    return 1
  fi

  printf "%s" "$loc"
}

function item::location_to_num() {
  local -r loc="${1:?}"
  local -r num="$(jq -r '.["'"$loc"'"]' "./scraped/location_to_number.json")"
  if [ "$num" == "null" ]; then
    log::err "Could not turn location into a number | num='$num'"
    printf "0"
    return 1
  fi

  printf "%s" "$num"
}

function item::inventory::from_name() {
  local -r item_obj="$(item::new::name "${1:?Give an item name to find inventory for}")"

  local item_nr
  if ! item_nr="$(item_obj::num "$item_obj")"; then
    log::err "Failed to get number for item | item='$item_obj'"
    return 1
  fi

  local ans
  if ! ans="$(jq -r '.["'"$item_nr"'"]' <<< "$(inventory)")"; then
    log::err "Could not read how many items were in inventory | item_obj='$item_obj' item_nr='$item_nr'"
    return 1
  fi

  if [ "$ans" == "null" ]; then
    log::debug "There is no key in inventory - answering '0' | key='$item_nr' item_obj='$item_obj'"
    printf "0"
    return 0
  fi

  # Return success
  echo "$ans"
}

function item::number_to_name() {
  local -r item_nr="${1:?}"
  jq -r \
    --arg value "$item_nr" \
    'to_entries[] | select(.value == $value) | .key' \
    "./scraped/item_to_number.json"
}
