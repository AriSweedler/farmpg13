function eat::breakfast_boost() {
  # Do work
  local output
  if ! output="$(worker "go=usemultitem" "id=661" "amt=1")"; then
    log::err "Failed to invoke worker"
    exit 1
  fi

  # Validate output
  log::warn "Unknown output to 'eat' | output='$output' output='$output'"
  set -x
  [ "$output" == "DEBUG IN TRACE" ] && true
  set +x

  log::info "Ate a breakfast boost | output='$output'"
}
