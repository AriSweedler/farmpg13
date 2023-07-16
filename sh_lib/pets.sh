function collect_pet_items() {
  # Do work
  local output
  if ! output="$(worker "go=collectallpetitems")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Validate output
  case "$output" in
    *item*collected) log::info "Successfully collected items | output='$output'" ;;
    "") log::err "Failed to collect pet items" ; return 1 ;;
    *) log::warn "Unknown output to collect pet items | output='$output'" ; return 1 ;;
  esac
}
