function fish::loc_to_num() {
  local -r loc_name="$(echo "${1:?}" | tr '-' '_')"
  local -r loc_nr="$(jq -r '.["'"$loc_name"'"]' "./scraped/fishloc_to_number.json")"
  if [ "$loc_nr" == "null" ]; then
    log::err "Could not turn fishing location into a number | loc_nr='$loc_nr' item_name='$item_name'"
    printf "0"
    return 1
  elif [ "$loc_nr" == "-1" ]; then
    log::err "You cannot fish there yet"
    printf "0"
    return 1
  fi

  printf "%s" "$loc_nr"
}

function fish::net::one() {
  local loc
  if ! loc="$(fish::loc_to_num "${1:?}")"; then
    log::err "Couldn't turn arg into location to fish"
    return 1
  fi

  # Send the HTTP request
  local -r mult=1
  local output
  if ! output="$(worker "go=castnet" "id=$loc" "mult=$mult")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Did casting the net fail?
  case "$output" in
    "") log::err "Not enough nets" ; return 1 ;;
    *) log::debug "Cast a net | loc='$loc' mult='$mult' output='$output'" ;;
  esac
  log::info "Cast a net | loc='$loc' mult='$mult'"
}

function fish::net::all() {
  local output
  while output="$(fish::net::one "$@")"; do
    # Are any fish at max capacity?
    if grep -q "grayscale" <<< "$output"; then
      log::info "Some items are at max capacity, selling them"
      sell_cap
    fi
  done
}
