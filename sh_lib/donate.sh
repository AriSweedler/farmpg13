function _donate() {
  # Parse args
  if ! item_id="$(item_obj::num "$1")"; then
    log::err "Failed to get item ID"
    return 1
  fi
  local -r amount="${2:?How many to donate}"

  # Do work
  local output
  if ! output="$(worker "go=donatecomm" "amt=${amount}")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Validate output
  if [ "$output" == "success" ]; then
    log::info "Donated to community center successfully | item='$1/$item_id' amount='$amount'"
  elif [ "$output" == "notenough" ]; then
    log::err "You do not have enough items to donate | output='$output'"
    return 1
  else
    log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'"
    return 1
  fi
}
