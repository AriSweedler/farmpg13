function chore::locksmith() {
  local -r amt="${1:?}"
  local -r id="491" # Grab Bag 07

  # Do work
  local output
  if ! output="$(worker "go=openitem" "id=$id" "amt=$amt")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Locksmith'd successfully | amt='$amt' output='$output'" ;;
    "") log::err "Failed to open grab bag 07 | output='$output;" ; return 1;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}
