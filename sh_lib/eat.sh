function eat::breakfast_boost() {
  # Do work
  local output
  if ! output="$(worker "go=usemultitem" "id=661" "amt=1")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Validate output
  log::warn "Unknown output to 'eat' | output='$output' output='$output'"
  set -x
  [ "$output" == "DEBUG IN TRACE" ] && true
  set +x

  log::info "Ate a breakfast boost | output='$output'"
}

function drink::orange_juice() {
  local -r amt="${1:?}"

  # Do work
  local output
  if ! output="$(worker "go=usemultitem" "id=84" "amt=$amt")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Successfully drank OJ" ;;
    "") log::err "Failed to drink OJ" ; return 1;;
    *) log::warn "Unknown output to drinking OJ | output='$output'" ; return 1 ;;
  esac
}
