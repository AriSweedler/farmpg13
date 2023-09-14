# Spiders for cutlass
### go=exchtradeaccept
### id=17
#
#convertxps
function exchange::trade() {
  local id="${1:?}"

  # Do work
  local output
  if ! output="$(worker "go=exchtradeaccept" "id=$id")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Successfully traded at the exchange center" ;;
    already) log::err "You have already made this trade" ; return 1 ;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function exchange::xp() {
  # Do work
  local output
  if ! output="$(worker "go=convertxps")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}
