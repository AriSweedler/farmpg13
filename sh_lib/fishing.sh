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
    exit 1
  fi

  # Did casting the net fail?
  case "$output" in
    "") log::err "Not enough nets" ; exit 1 ;;
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
