function camp_mailbox() {
  while True; do
    collect_mail
    sleep $(bc <<< "$(rapid_tap_delay) * 20 + $(rapid_tap_delay)")
  done
}

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
    log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'"
    return 1
  fi
}
