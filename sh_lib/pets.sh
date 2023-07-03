function collect_pet_items() {
  # Do work
  local output
  if ! output="$(worker "go=collectallpetitems")"; then
    log::err "Failed to invoke worker"
    exit 1
  fi

  # Validate output
  log::warn "Unknown output to ${FUNCNAME[0]} | output='$output'"
}
