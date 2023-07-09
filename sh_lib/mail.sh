function collect_mail() {
  # Do work
  local output
  if ! output="$(worker "go=collectallmailitems")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Validate output
  if [ "$output" == "success" ]; then
    log::info "Successfully collected items"
  else
    log::warn "Unknown output to 'collectallmailitems' | output='$output'"
    return 1
  fi
}
