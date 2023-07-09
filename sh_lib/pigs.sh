function feed_mill::load::corn() {
  # Parse args
  local -r amt="${1:?How many corns to load}"
  if ! item::ensure_have "corn" "$amt"; then
    log::err "Could not ensure we had enough corn"
    return 1
  fi

  # Do work
  local output
  if ! output="$(worker "go=loadfeedmill" "id=45865425578" "amt=$amt")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Loaded feed mill successfully" ;;
    "") log::err "Failed to load feed mill" ; return 1;;
    *) log::warn "Unknown output to 'load_feed_mill' | output='$output'" ; return 1 ;;
  esac
}


function pig::feed_one() {
  # Parse args
  local -r pig_nr="${1:?Starting pig}"

  # Do work
  local output
  if ! output="$(worker "go=feedpig" "num=${pig_nr}")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Validate output
  case "$output" in
    success)
      log::debug "Successfully fed pig | pig_nr='$pig_nr'"
      log::info "Successfully fed pig"
      ;;
    alreadytoday)
      log::err "You already fed this pig today | pig_nr='$pig_nr'"
      return 1
      ;;
    *)
      log::warn "Unknown output to pig::feed_one | output='$output'"
      return 1
      ;;
  esac
}

function feed_pigs() {
  local -r start="${1:?First pig to feed}"
  local -r amount="${2:?Number of pigs to feed}"

  # Make sure we have enough - do work if necessary
  if ! item::ensure_have "corn" "$amount"; then
    log::err "Could not ensure we have enough corn to feed pigs | amount='$amount'"
    return 1
  fi

  # Feed the pigs
  for ((i = start; i < start + amount; i++)); do
    pig::feed_one "$i"
  done
  log::info "Fed all the pigs | amount='$amount'"
}
